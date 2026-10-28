param(
    [Parameter(Mandatory = $true)][string]$InstallerPath,
    [Parameter(Mandatory = $true)][string]$TestDirectory,
    [Parameter(Mandatory = $true)][string]$PayloadDirectory
)
$ErrorActionPreference = 'Stop'
$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$payload = (Resolve-Path -LiteralPath $PayloadDirectory).Path
$testRoot = [IO.Path]::GetFullPath($TestDirectory)
if (Test-Path -LiteralPath $testRoot) { throw 'Use a new, empty test directory.' }
$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\KayLucas.LocalMarkdownEditor'
if (Test-Path -LiteralPath $registryPath) {
    throw 'An existing app installation is registered. Refusing to alter it during testing.'
}
$startMenu = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\로컬 Markdown 에디터'
if (Test-Path -LiteralPath $startMenu) { throw 'Start menu folder already exists. Refusing to alter it.' }
$setup = Start-Process -FilePath $installer -ArgumentList @('/S', "/D=$testRoot") -WindowStyle Hidden -PassThru
if (-not $setup.WaitForExit(30000)) { throw 'Installer did not finish within 30 seconds.' }
if ($setup.ExitCode -ne 0) { throw "Installer failed with exit code $($setup.ExitCode)" }
$entry = Get-ItemProperty -LiteralPath $registryPath
if ($entry.InstallLocation -ne $testRoot) { throw 'Unexpected registered install location.' }
$payloadFiles = @(Get-ChildItem -LiteralPath $payload -Recurse -File)
foreach ($file in $payloadFiles) {
    $relative = [IO.Path]::GetRelativePath($payload, $file.FullName)
    $installed = Join-Path $testRoot $relative
    if (-not (Test-Path -LiteralPath $installed)) { throw "Missing installed file: $relative" }
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $installed).Hash) {
        throw "Installed file differs: $relative"
    }
}
$shortcutCount = @(Get-ChildItem -LiteralPath $startMenu -Filter '*.lnk').Count
if ($shortcutCount -ne 3) { throw 'Expected three Start menu shortcuts.' }
$userDocument = Join-Path $testRoot '__installer_user_document_keep__.md'
$userText = '# Keep this user document after uninstall'
[IO.File]::WriteAllText($userDocument, $userText)
$editedExample = Join-Path $testRoot '예제\시작하기.md'
$exampleText = '# Keep my edited example after upgrade and uninstall'
[IO.File]::WriteAllText($editedExample, $exampleText)
$upgrade = Start-Process -FilePath $installer -ArgumentList @('/S', "/D=$testRoot") -WindowStyle Hidden -PassThru
if (-not $upgrade.WaitForExit(30000) -or $upgrade.ExitCode -ne 0) { throw 'Upgrade installation failed.' }
if ([IO.File]::ReadAllText($editedExample) -ne $exampleText -or [IO.File]::ReadAllText($userDocument) -ne $userText) {
    throw 'Upgrade overwrote a user document.'
}
$uninstallPath = Join-Path $testRoot 'uninstall.exe'
$uninstaller = Start-Process -FilePath $uninstallPath -ArgumentList '/S' -WindowStyle Hidden -PassThru
if (-not $uninstaller.WaitForExit(30000)) { throw 'Uninstaller did not finish within 30 seconds.' }
$watch = [Diagnostics.Stopwatch]::StartNew()
while (((Test-Path -LiteralPath $registryPath) -or (Test-Path -LiteralPath $uninstallPath)) -and $watch.Elapsed.TotalSeconds -lt 30) {
    [Threading.Thread]::Sleep(100)
}
if (Test-Path -LiteralPath $registryPath) { throw 'Uninstall registration was not removed.' }
if (Test-Path -LiteralPath $startMenu) { throw 'Start menu shortcuts were not removed.' }
foreach ($file in $payloadFiles) {
    $relative = [IO.Path]::GetRelativePath($payload, $file.FullName)
    if ($file.Extension -in @('.md', '.markdown') -or $relative.StartsWith('예제\', [StringComparison]::OrdinalIgnoreCase)) {
        continue
    }
    if (Test-Path -LiteralPath (Join-Path $testRoot $relative)) { throw "App file remains: $relative" }
}
if ([IO.File]::ReadAllText($userDocument) -ne $userText) { throw 'User document was not preserved.' }
if ([IO.File]::ReadAllText($editedExample) -ne $exampleText) { throw 'Edited example was not preserved.' }
if (Test-Path -LiteralPath (Join-Path $testRoot '.install-owner')) { throw 'Installation marker remains.' }
$report = [ordered]@{
    installer = [IO.Path]::GetFileName($installer)
    sha256 = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    installation = 'passed'
    payloadFilesVerified = $payloadFiles.Count
    runtimeIncluded = @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')
    startMenuShortcuts = $shortcutCount
    uninstall = 'passed'
    userDocumentPreserved = $true
    upgradePreservesUserDocuments = $true
    editedExamplePreserved = $true
    uninstallRegistryRemoved = $true
    uiWizardManuallyVerified = $false
    cleanPcWithoutDevelopmentToolsVerified = $false
    digitalSignature = 'not signed'
}
$reportPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'verification\installer_results.json'
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding utf8
$report | ConvertTo-Json -Depth 5
