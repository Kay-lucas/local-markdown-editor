# Create project-local directory junctions when Windows Developer Mode is off.
# This changes no Windows settings and does not copy or edit the package cache.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $projectRoot '.flutter-plugins-dependencies'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw 'Run flutter pub get once to generate .flutter-plugins-dependencies first.'
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$junctionRoot = Join-Path $projectRoot 'windows\flutter\ephemeral\.plugin_symlinks'
New-Item -ItemType Directory -Path $junctionRoot -Force | Out-Null
foreach ($plugin in $manifest.plugins.windows) {
    $destination = Join-Path $junctionRoot $plugin.name
    if (-not (Test-Path -LiteralPath $destination)) {
        $target = [System.IO.Path]::GetFullPath($plugin.path)
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            throw "Missing package: $($plugin.name)"
        }
        New-Item -ItemType Junction -Path $destination -Target $target | Out-Null
        Write-Output "Prepared $($plugin.name)"
    }
}
