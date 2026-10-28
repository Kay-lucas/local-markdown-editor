param(
    [Parameter(Mandatory = $true)][string]$NsisCompiler,
    [Parameter(Mandatory = $true)][string]$PayloadDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$MsvcRuntimeDirectory
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = (Resolve-Path -LiteralPath $NsisCompiler).Path
$payloadPath = (Resolve-Path -LiteralPath $PayloadDirectory).Path
$runtimePath = (Resolve-Path -LiteralPath $MsvcRuntimeDirectory).Path
$versionMatch = [regex]::Match((Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'pubspec.yaml')), '(?m)^version:\s*(\d+\.\d+\.\d+)')
if (-not $versionMatch.Success) { throw 'Unable to determine app version' }
$appVersion = $versionMatch.Groups[1].Value
if (-not (Test-Path -LiteralPath (Join-Path $payloadPath 'local_markdown_editor.exe'))) {
    throw 'Build the Windows Release app before packaging.'
}
if ($runtimePath -match 'debug_nonredist' -or $runtimePath -notmatch '[\\/]x64[\\/]Microsoft\.VC\d+\.CRT$') {
    throw 'Choose the unmodified x64 release CRT directory from Visual Studio Redist.'
}
$expectedRuntimeFiles = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
foreach ($fileName in $expectedRuntimeFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $runtimePath $fileName))) {
        throw "Missing runtime file: $fileName"
    }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
$stagePath = Join-Path $projectRoot 'build\installer\payload'
if (Test-Path -LiteralPath $stagePath) {
    $resolvedStage = (Resolve-Path -LiteralPath $stagePath).Path
    if (-not $resolvedStage.StartsWith($projectRoot + '\build\installer\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Unexpected staging directory; refusing to delete it.'
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
New-Item -ItemType Directory -Path $stagePath -Force | Out-Null
Get-ChildItem -LiteralPath $payloadPath -Force | Copy-Item -Destination $stagePath -Recurse -Force
Get-ChildItem -LiteralPath $runtimePath -Filter '*.dll' -File | Copy-Item -Destination $stagePath
Copy-Item -LiteralPath (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.md') -Destination $stagePath
Copy-Item -LiteralPath (Join-Path $projectRoot 'installer\사용안내.md') -Destination (Join-Path $stagePath '사용안내.md') -Force
if (Test-Path -LiteralPath (Join-Path $projectRoot 'LICENSE')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination $stagePath
}
$runtimeHashes = Get-ChildItem -LiteralPath $runtimePath -Filter '*.dll' -File | ForEach-Object {
    [pscustomobject]@{ File = $_.Name; SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
}
$runtimeHashes | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectRoot 'build\installer\runtime-hashes.json') -Encoding utf8
$uninstallLines = [Collections.Generic.List[string]]::new()
foreach ($file in Get-ChildItem -LiteralPath $stagePath -Recurse -File) {
    $relativePath = [IO.Path]::GetRelativePath($stagePath, $file.FullName)
    if ($relativePath.Contains('"') -or $relativePath.Contains('$')) { throw 'Unsupported payload filename' }
    if ($file.Extension -in @('.md', '.markdown') -or $relativePath.StartsWith('예제\', [StringComparison]::OrdinalIgnoreCase)) {
        continue
    }
    $uninstallLines.Add('Delete "$INSTDIR\' + $relativePath + '"')
}
$directories = @(Get-ChildItem -LiteralPath $stagePath -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending)
foreach ($directory in $directories) {
    $relativePath = [IO.Path]::GetRelativePath($stagePath, $directory.FullName)
    $uninstallLines.Add('RMDir "$INSTDIR\' + $relativePath + '"')
}
$includePath = Join-Path $projectRoot 'build\installer\uninstall_files.nsh'
$uninstallLines | Set-Content -LiteralPath $includePath -Encoding utf8BOM
$installerPath = Join-Path $outputPath "LocalMarkdownEditor-Setup-$appVersion-x64.exe"
& $compilerPath '/V3' '/INPUTCHARSET' 'UTF8' "/DPAYLOAD_DIR=$stagePath" "/DOUTPUT_FILE=$installerPath" "/DAPP_VERSION=$appVersion" "/DUNINSTALL_INCLUDE=$includePath" (Join-Path $projectRoot 'installer\windows.nsi')
if ($LASTEXITCODE -ne 0) { throw 'NSIS compilation failed' }
Write-Output "Installer: $installerPath"
Get-FileHash -LiteralPath $installerPath -Algorithm SHA256
