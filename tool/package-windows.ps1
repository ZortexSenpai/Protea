<#
.SYNOPSIS
    Build the Windows release bundle and package it as a distributable zip.

.DESCRIPTION
    The zip contains one folder (protea-<version>-windows-<arch>\) with
    install-windows.ps1 and the protea\ application folder — users extract it
    and run install-windows.ps1 to install or update Protea.

.PARAMETER NoBuild
    Package an already-built release bundle instead of building first.

.EXAMPLE
    tool\package-windows.ps1
    Build, then create dist\protea-<version>-windows-<arch>.zip.

.EXAMPLE
    tool\package-windows.ps1 -NoBuild
    Package an already-built bundle.
#>
[CmdletBinding()]
param(
    [switch] $NoBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoDir = Split-Path -Parent $PSScriptRoot
$BinName = 'protea'
$AppName = 'Protea'

switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { $Arch = 'x64' }
    'ARM64' { $Arch = 'arm64' }
    default { Write-Error "Unsupported architecture $env:PROCESSOR_ARCHITECTURE" }
}
$BundleDir = Join-Path $RepoDir "build\windows\$Arch\runner\Release"

# --- Build -------------------------------------------------------------------
if (-not $NoBuild) {
    $flutter = (Get-Command flutter -ErrorAction SilentlyContinue)
    if (-not $flutter) {
        Write-Error "flutter not found on PATH."
    }
    Write-Host "Building $AppName (windows $Arch, release) ..."
    Push-Location $RepoDir
    try {
        & $flutter.Source build windows --release
        if ($LASTEXITCODE -ne 0) { Write-Error "flutter build windows failed ($LASTEXITCODE)." }
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path (Join-Path $BundleDir "$BinName.exe"))) {
    Write-Error "Release bundle not found at $BundleDir."
}

# --- Package -----------------------------------------------------------------
$versionMatch = Select-String -Path (Join-Path $RepoDir 'pubspec.yaml') `
                              -Pattern '^version:\s*([0-9][^+\s]*)' |
                Select-Object -First 1
$Version = if ($versionMatch) { $versionMatch.Matches[0].Groups[1].Value } else { 'unknown' }

$PkgName = "$BinName-$Version-windows-$Arch"
$DistDir = Join-Path $RepoDir 'dist'
$Staging = Join-Path $DistDir $PkgName
$ZipPath = Join-Path $DistDir "$PkgName.zip"

Write-Host "Packaging $PkgName.zip ..."
foreach ($stale in @($Staging, $ZipPath)) {
    if (Test-Path $stale) { Remove-Item -Recurse -Force $stale }
}
New-Item -ItemType Directory -Path (Join-Path $Staging $BinName) -Force | Out-Null

Copy-Item -Path (Join-Path $BundleDir '*') `
          -Destination (Join-Path $Staging $BinName) -Recurse -Force
# Ship the icon alongside the exe, the way the Linux package ships protea.png.
Copy-Item (Join-Path $RepoDir 'windows\runner\resources\app_icon.ico') `
          (Join-Path $Staging "$BinName\$BinName.ico") -Force
Copy-Item (Join-Path $RepoDir 'install-windows.ps1') `
          (Join-Path $Staging 'install-windows.ps1') -Force

$readme = @"
$AppName $Version for Windows ($Arch)

To install or update, right-click install-windows.ps1 and choose
"Run with PowerShell", or open a PowerShell window in this folder and run:

    powershell -ExecutionPolicy Bypass -File .\install-windows.ps1

Windows marks files from the internet as blocked. If the script refuses to
run, unblock it first:

    Unblock-File .\install-windows.ps1

To install for all users:          run the same command in an elevated
                                   PowerShell with -AllUsers
To add a desktop shortcut:         -DesktopShortcut
To uninstall (chat data is kept):  -Uninstall
"@
Set-Content -Path (Join-Path $Staging 'README.txt') -Value $readme -Encoding utf8

Compress-Archive -Path $Staging -DestinationPath $ZipPath -CompressionLevel Optimal
Remove-Item -Recurse -Force $Staging

$sizeMb = [math]::Round((Get-Item $ZipPath).Length / 1MB, 1)
Write-Host "Done: $ZipPath (${sizeMb}M)"
