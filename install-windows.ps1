<#
.SYNOPSIS
    Protea Windows installer / updater.

.DESCRIPTION
    Works from a release zip (this script next to a protea\ folder) or from a
    source checkout (after `flutter build windows --release`). Running it again
    updates an existing installation in place. Chat data is never touched.

.PARAMETER AllUsers
    Install system-wide into %ProgramFiles% instead of per-user. Needs an
    elevated PowerShell.

.PARAMETER Uninstall
    Remove the app again. Chat data is kept.

.PARAMETER Bundle
    Use this folder as the application bundle instead of the default locations.

.PARAMETER DesktopShortcut
    Also place a shortcut on the desktop (the Start Menu entry is always made).

.EXAMPLE
    .\install-windows.ps1
    Install or update for the current user.

.EXAMPLE
    .\install-windows.ps1 -Uninstall
    Remove the app (keeps chat data).
#>
[CmdletBinding()]
param(
    [switch] $AllUsers,
    [switch] $Uninstall,
    [switch] $DesktopShortcut,
    [string] $Bundle,
    # Set when the script re-launched itself from a temp copy so it can delete
    # its own install folder. Not meant to be passed by hand.
    [switch] $Relaunched
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$AppName   = 'Protea'
$BinName   = 'protea'
$Publisher = 'energy.vgt'
$Comment   = 'A cross-platform Matrix chat client built with Flutter'

# Must match the WindowsInitializationSettings in lib/src/notifications.dart.
# The app registers this id under HKCU itself on first launch (that is how
# toasts work without an MSIX package), so installing does not have to — but
# uninstalling should clean it up again.
$AppUserModelId = 'energy.vgt.Protea'

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath

# --- Install locations: system-wide with -AllUsers, per-user otherwise -------
# NOTE: the app stores chat data in %APPDATA%\energy.vgt\protea (the roaming
# app-data dir path_provider derives from the exe's version info), so the app
# files must live somewhere else — never install into that path.
if ($AllUsers) {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "-AllUsers needs an elevated PowerShell (Run as administrator)."
    }
    $InstallDir   = Join-Path $env:ProgramFiles $AppName
    $StartMenuDir = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
    $DesktopDir   = Join-Path $env:PUBLIC 'Desktop'
    $UninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
    $PathScope    = 'Machine'
} else {
    $InstallDir   = Join-Path $env:LOCALAPPDATA "Programs\$AppName"
    $StartMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $DesktopDir   = [Environment]::GetFolderPath('Desktop')
    $UninstallKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
    $PathScope    = 'User'
}
$StartMenuLink = Join-Path $StartMenuDir "$AppName.lnk"
$DesktopLink   = Join-Path $DesktopDir "$AppName.lnk"
$DataDir       = Join-Path $env:APPDATA "$Publisher\$BinName"

function Test-SamePath([string] $a, [string] $b) {
    if (-not $a -or -not $b) { return $false }
    return $a.TrimEnd('\') -ieq $b.TrimEnd('\')
}

# PATH is edited through the registry rather than
# [Environment]::SetEnvironmentVariable: that API expands any %VAR% in the
# existing value and writes the result back as a plain string, which silently
# breaks entries other installers left there.
$PathKey = if ($PathScope -eq 'Machine') {
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
} else {
    'HKCU:\Environment'
}

function Get-RawPath {
    $key = Get-Item $PathKey
    return [string] $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
}

function Set-RawPath([string] $value) {
    Set-ItemProperty -Path $PathKey -Name 'Path' -Value $value -Type ExpandString
    # Registry writes alone do not reach already-running processes; Explorer
    # only refreshes the environment new terminals inherit on this broadcast.
    if (-not ('Win32.NativeMethods' -as [type])) {
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam,
    string lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@
    }
    $result = [IntPtr]::Zero
    # HWND_BROADCAST, WM_SETTINGCHANGE, SMTO_ABORTIFHUNG, 5s
    [void][Win32.NativeMethods]::SendMessageTimeout(
        [IntPtr] 0xffff, 0x1A, [IntPtr]::Zero, 'Environment', 2, 5000, [ref] $result)
}

# Both keep every other segment byte-for-byte, empty ones included: PATH is
# shared with every other installer on the machine and is not ours to tidy.
function Remove-FromPath([string] $dir) {
    $current = Get-RawPath
    if (-not $current) { return }
    $kept = @(($current -split ';') | Where-Object { -not ($_ -and (Test-SamePath $_ $dir)) })
    Set-RawPath ($kept -join ';')
}

function Add-ToPath([string] $dir) {
    $current = Get-RawPath
    foreach ($entry in ($current -split ';')) {
        if ($entry -and (Test-SamePath $entry $dir)) { return }
    }
    if ($current -and -not $current.EndsWith(';')) { $current += ';' }
    Set-RawPath ($current + $dir)
}

function Assert-NotRunning {
    if (Get-Process -Name $BinName -ErrorAction SilentlyContinue) {
        Write-Error "$AppName is running. Close it and run this script again."
    }
}

# --- Uninstall ---------------------------------------------------------------
if ($Uninstall) {
    # The Add/Remove Programs entry calls the copy of this script that lives
    # inside the install folder, and that copy cannot delete the folder it is
    # sitting in. Re-run from a temp copy instead.
    if (-not $Relaunched -and (Test-SamePath $ScriptDir $InstallDir)) {
        $temp = Join-Path ([IO.Path]::GetTempPath()) ("protea-uninstall-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $temp | Out-Null
        $tempScript = Join-Path $temp 'install-windows.ps1'
        Copy-Item $ScriptPath $tempScript
        $childArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tempScript,
                       '-Uninstall', '-Relaunched')
        if ($AllUsers) { $childArgs += '-AllUsers' }
        Start-Process -FilePath 'powershell.exe' -ArgumentList $childArgs -Wait
        exit 0
    }

    Assert-NotRunning
    Write-Host "Removing $AppName from $InstallDir ..."
    if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
    foreach ($link in @($StartMenuLink, $DesktopLink)) {
        if (Test-Path $link) { Remove-Item -Force $link }
    }
    Remove-FromPath $InstallDir
    if (Test-Path $UninstallKey) { Remove-Item -Recurse -Force $UninstallKey }

    # Drop the toast registration the app made for itself, so no stale entry is
    # left behind under Settings > Notifications.
    foreach ($key in @("HKCU:\Software\Classes\AppUserModelId\$AppUserModelId",
                       "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications\Backup\$AppUserModelId")) {
        if (Test-Path $key) { Remove-Item -Recurse -Force $key -ErrorAction SilentlyContinue }
    }

    Write-Host "$AppName uninstalled."
    Write-Host "Chat data in $DataDir was kept; delete that folder to remove it too."
    exit 0
}

# --- Locate the application bundle -------------------------------------------
# 1. -Bundle DIR   2. protea\ next to this script (release zip)
# 3. build\windows\<arch>\runner\Release (source checkout)
if (-not $Bundle) {
    $candidates = @(Join-Path $ScriptDir $BinName)
    foreach ($arch in @('x64', 'arm64')) {
        $candidates += (Join-Path $ScriptDir "build\windows\$arch\runner\Release")
    }
    # Flutter before 3.13 built into an arch-less folder.
    $candidates += (Join-Path $ScriptDir 'build\windows\runner\Release')
    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate "$BinName.exe")) { $Bundle = $candidate; break }
    }
}
if (-not $Bundle -or -not (Test-Path (Join-Path $Bundle "$BinName.exe"))) {
    Write-Error ("Application bundle not found. Expected a '$BinName\' folder next to " +
                 "this script (release zip) or build\windows\<arch>\runner\Release " +
                 "(run: flutter build windows --release).")
}
$Bundle = (Resolve-Path $Bundle).Path
if (Test-SamePath $Bundle $InstallDir) {
    Write-Error "The bundle is already the install folder ($InstallDir); nothing to do."
}

$Version = (Get-Item (Join-Path $Bundle "$BinName.exe")).VersionInfo.ProductVersion
if (-not $Version) { $Version = '0.0.0' }

# Icon: bundled protea.ico (release zip), else the runner resource (checkout)
$IconSrc = $null
foreach ($c in @((Join-Path $Bundle "$BinName.ico"),
                 (Join-Path $ScriptDir 'windows\runner\resources\app_icon.ico'))) {
    if (Test-Path $c) { $IconSrc = $c; break }
}

# --- Install / update the application folder ---------------------------------
Assert-NotRunning
if (Test-Path $InstallDir) {
    Write-Host "Updating $AppName in $InstallDir ..."
    # Empty the folder rather than delete it: Windows refuses to delete a
    # folder that is some process's current directory (a terminal opened in
    # it, say), and failing there would leave the old files already gone.
    Get-ChildItem -LiteralPath $InstallDir -Force | Remove-Item -Recurse -Force
} else {
    Write-Host "Installing $AppName to $InstallDir ..."
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path (Join-Path $Bundle '*') -Destination $InstallDir -Recurse -Force

$InstalledExe = Join-Path $InstallDir "$BinName.exe"
if ($IconSrc) { Copy-Item $IconSrc (Join-Path $InstallDir "$BinName.ico") -Force }
# Keep a copy next to the app so the Add/Remove Programs entry has something
# to call.
Copy-Item $ScriptPath (Join-Path $InstallDir 'install-windows.ps1') -Force

# --- Shortcuts ---------------------------------------------------------------
function New-Shortcut([string] $path) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($path)
    $link.TargetPath       = $InstalledExe
    $link.WorkingDirectory = $InstallDir
    $link.Description      = $Comment
    $link.IconLocation     = "$InstalledExe,0"
    $link.Save()
}

Write-Host "Creating Start Menu shortcut $StartMenuLink ..."
New-Shortcut $StartMenuLink
if ($DesktopShortcut) {
    Write-Host "Creating desktop shortcut $DesktopLink ..."
    New-Shortcut $DesktopLink
}

# --- Command-line access -----------------------------------------------------
Add-ToPath $InstallDir

# --- Add/Remove Programs entry -----------------------------------------------
$uninstallCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$InstallDir\install-windows.ps1"" -Uninstall"
if ($AllUsers) { $uninstallCmd += ' -AllUsers' }
$sizeKb = [int]((Get-ChildItem -Recurse -File $InstallDir |
                 Measure-Object -Property Length -Sum).Sum / 1KB)
New-Item -Path $UninstallKey -Force | Out-Null
$entries = [ordered]@{
    DisplayName     = $AppName
    DisplayVersion  = $Version
    Publisher       = $Publisher
    DisplayIcon     = $InstalledExe
    InstallLocation = $InstallDir
    UninstallString = $uninstallCmd
    EstimatedSize   = $sizeKb
    NoModify        = 1
    NoRepair        = 1
}
foreach ($name in $entries.Keys) {
    $type = if ($entries[$name] -is [int]) { 'DWord' } else { 'String' }
    New-ItemProperty -Path $UninstallKey -Name $name -Value $entries[$name] `
                     -PropertyType $type -Force | Out-Null
}

Write-Host ""
Write-Host "$AppName $Version installed successfully."
Write-Host "  Application: $InstallDir"
Write-Host "  Launcher:    $StartMenuLink"
Write-Host "  Command:     $BinName (open a new terminal to pick up the PATH change)"
Write-Host "  Chat data:   $DataDir"
