# Run the installed SDK directly; no SDK files or Windows settings are modified.
$ErrorActionPreference = 'Stop'
$flutterCommand = Get-Command flutter.bat -ErrorAction Stop
$sdkRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
$dartExecutable = Join-Path $sdkRoot 'bin\cache\dart-sdk\bin\dart.exe'
$toolSnapshot = Join-Path $sdkRoot 'bin\cache\flutter_tools.snapshot'
$packageConfig = Join-Path $sdkRoot 'packages\flutter_tools\.dart_tool\package_config.json'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & $dartExecutable "--packages=$packageConfig" $toolSnapshot @args
    $resultCode = $LASTEXITCODE
    if ($resultCode -ne 0 -and $args.Count -ge 2 -and $args[0] -eq 'pub' -and $args[1] -eq 'get') {
        & (Join-Path $PSScriptRoot 'prepare_windows_plugins.ps1')
        & $dartExecutable "--packages=$packageConfig" $toolSnapshot @args
        $resultCode = $LASTEXITCODE
    }
    exit $resultCode
} finally {
    Pop-Location
}
