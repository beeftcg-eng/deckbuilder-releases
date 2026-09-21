<#
.SYNOPSIS
    Installs or updates Pawmodoro and/or Deckbuilder from their latest GitHub releases.

.DESCRIPTION
    Downloads the newest release of each app, checks the download against the
    checksum GitHub lists for it, and runs the app's own installer:

      * Pawmodoro  - desktop notes / checklist / pomodoro timer. Needs Python 3
                     (python.org, or the Microsoft Store). Installs into
                     %LOCALAPPDATA%\Pawmodoro and adds a Desktop shortcut.
                     Your notes and settings live in %APPDATA%\Pawmodoro and are
                     never touched. Restarts itself when the update is done.
      * Deckbuilder - trading card deckbuilder (Riftbound, One Piece, Pokemon,
                     Magic). Runs its normal installer. The installer isn't
                     code-signed, so Windows SmartScreen may say "Windows
                     protected your PC": click "More info", then "Run anyway".

    It is safe to run again any time; an app that is already up to date is
    skipped (use -Force to reinstall it anyway). Both apps can also update
    themselves from inside once they are installed.

.PARAMETER App
    Pawmodoro, Deckbuilder or Both. If left out, you are asked.

.PARAMETER Force
    Reinstall even if the installed version is already the latest.

.PARAMETER SilentDeckbuilder
    Run the Deckbuilder installer with no window (it may not start the app afterwards).

.PARAMETER NoPause
    Don't wait for Enter at the end (for use from other scripts).

.PARAMETER DryRun
    Download and check everything, but don't run any installer.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-Pawmodoro-and-Deckbuilder.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-Pawmodoro-and-Deckbuilder.ps1 -App Pawmodoro

.NOTES
    If Windows refuses to run the file because it came from the internet, run
    Unblock-File .\Install-Pawmodoro-and-Deckbuilder.ps1 first (or use the -ExecutionPolicy Bypass form above).
#>
[CmdletBinding()]
param(
    [ValidateSet('Ask', 'Both', 'Pawmodoro', 'Deckbuilder')]
    [string]$App = 'Ask',
    [switch]$Force,
    [switch]$SilentDeckbuilder,
    [switch]$NoPause,
    [switch]$DryRun
)

$PawmodoroRepo = 'beeftcg-eng/pawmodoro'
$DeckbuilderRepo = 'beeftcg-eng/deckbuilder-releases'
$UserAgent = 'Install-Pawmodoro-and-Deckbuilder'

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Windows PowerShell 5.1 crawls on big downloads with the progress bar on
try {
    # Older Windows PowerShell defaults to protocols GitHub no longer accepts.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }

function Write-Step([string]$Message) { Write-Host ''; Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "    $Message" -ForegroundColor Green }
function Write-Note([string]$Message) { Write-Host "    $Message" -ForegroundColor Yellow }

function Get-LatestRelease([string]$Repo) {
    try {
        Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = $UserAgent; 'Accept' = 'application/vnd.github+json' }
    } catch {
        throw "Couldn't reach GitHub to find the latest $Repo release ($($_.Exception.Message)). Check your internet connection and try again."
    }
}

function ConvertTo-VersionOrNull([string]$Text) {
    if ($Text -match '(\d+)\.(\d+)\.(\d+)') { return [version]"$($Matches[1]).$($Matches[2]).$($Matches[3])" }
    return $null
}

function Save-Download($Asset, [string]$Destination) {
    Write-Host ("    Downloading {0} ({1:N0} MB)..." -f $Asset.name, ($Asset.size / 1MB))
    Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $Destination -UseBasicParsing -Headers @{ 'User-Agent' = $UserAgent }
    if ($Asset.size -and ((Get-Item $Destination).Length -ne $Asset.size)) {
        Remove-Item $Destination -Force -ErrorAction SilentlyContinue
        throw "The download of $($Asset.name) was cut short. Please try again."
    }
    # GitHub lists a SHA-256 for each uploaded file ("sha256:<hex>"); refuse anything that doesn't match it.
    if ($Asset.digest -and ([string]$Asset.digest).StartsWith('sha256:')) {
        $expected = ([string]$Asset.digest).Substring(7)
        $actual = (Get-FileHash -Path $Destination -Algorithm SHA256).Hash
        if ($actual -ne $expected) {
            Remove-Item $Destination -Force -ErrorAction SilentlyContinue
            throw "The download of $($Asset.name) doesn't match the checksum GitHub lists for it, so it was thrown away."
        }
        Write-Ok 'Checksum verified.'
    }
}

function New-WorkFolder([string]$Name) {
    $path = Join-Path ([IO.Path]::GetTempPath()) $Name
    if (Test-Path $path) { Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

# ---------------------------------------------------------------- Pawmodoro

function Test-PythonWorks([string]$Exe, [string[]]$Extra) {
    try {
        $output = & $Exe @Extra --version 2>&1
        return ($LASTEXITCODE -eq 0) -and ("$output" -match '^Python 3\.')
    } catch { return $false }
}

function Test-Python3 {
    # The same lookup Pawmodoro's installer does: the "py" launcher first, then "python". (The Microsoft
    # Store's placeholder "python" prints a message and fails, so it isn't mistaken for a real one.)
    if ((Get-Command py -ErrorAction SilentlyContinue) -and (Test-PythonWorks 'py' @('-3'))) { return $true }
    if ((Get-Command python -ErrorAction SilentlyContinue) -and (Test-PythonWorks 'python' @())) { return $true }
    return $false
}

function Get-InstalledPawmodoroVersion {
    if (-not $env:LOCALAPPDATA) { return $null }
    $file = Join-Path $env:LOCALAPPDATA 'Pawmodoro\version.py'
    if (-not (Test-Path $file)) { return $null }
    return ConvertTo-VersionOrNull (Get-Content $file -Raw)
}

function Install-Pawmodoro {
    Write-Step 'Pawmodoro'
    $release = Get-LatestRelease $PawmodoroRepo
    $latest = ConvertTo-VersionOrNull $release.tag_name
    $installed = Get-InstalledPawmodoroVersion
    $installedText = 'not installed'
    if ($installed) { $installedText = "v$installed" }
    Write-Host "    Latest: v$latest    Installed: $installedText"

    if ($installed -and $latest -and ($installed -ge $latest) -and -not $Force) {
        Write-Ok 'Already up to date.'
        return 'already up to date'
    }
    if (-not (Test-Python3)) {
        throw ("Pawmodoro needs Python 3, which wasn't found. Install it from https://www.python.org/downloads/ " +
               "(tick 'Add python.exe to PATH' in the installer) or from the Microsoft Store, then run this again.")
    }
    $asset = $release.assets | Where-Object { $_.name -like '*-windows.zip' } | Select-Object -First 1
    if (-not $asset) { throw "The latest Pawmodoro release ($($release.tag_name)) has no Windows download attached." }

    $work = New-WorkFolder 'pawmodoro-installer'
    try {
        $zip = Join-Path $work $asset.name
        Save-Download $asset $zip
        Write-Host '    Unpacking...'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $work 'unpacked'))
        $installer = Get-ChildItem -Path (Join-Path $work 'unpacked') -Recurse -Filter 'install.ps1' | Select-Object -First 1
        if (-not $installer) { throw 'The download has no install.ps1 in it.' }

        if ($DryRun) {
            Write-Note "Dry run: would run $($installer.FullName) -Relaunch"
            return 'dry run (downloaded and verified)'
        }
        Write-Host '    Installing (this can take a minute the first time)...'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer.FullName -Relaunch | Out-Host   # Out-Host: keep its output out of this function's return value
        if ($LASTEXITCODE -ne 0) { throw "Pawmodoro's installer reported an error (exit code $LASTEXITCODE); see the messages above." }
        Write-Ok "Pawmodoro v$latest installed. It should open by itself; there's also a Desktop shortcut."
        return "installed v$latest"
    } finally {
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --------------------------------------------------------------- Deckbuilder

function Get-InstalledDeckbuilderVersion {
    # Best effort: look for "Deckbuilder" among the installed programs.
    $keys = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    foreach ($key in $keys) {
        $entry = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'Deckbuilder*' } | Select-Object -First 1
        if ($entry) { return ConvertTo-VersionOrNull ([string]$entry.DisplayVersion) }
    }
    return $null
}

function Install-Deckbuilder {
    Write-Step 'Deckbuilder'
    $release = Get-LatestRelease $DeckbuilderRepo
    $latest = ConvertTo-VersionOrNull $release.tag_name
    $installed = Get-InstalledDeckbuilderVersion
    $installedText = 'not found'
    if ($installed) { $installedText = "v$installed" }
    Write-Host "    Latest: v$latest    Installed: $installedText"

    if ($installed -and $latest -and ($installed -ge $latest) -and -not $Force) {
        Write-Ok 'Already up to date.'
        return 'already up to date'
    }
    $asset = $release.assets | Where-Object { $_.name -eq 'Deckbuilder-Setup.exe' } | Select-Object -First 1
    if (-not $asset) { throw "The latest Deckbuilder release ($($release.tag_name)) has no Windows installer attached." }

    $work = New-WorkFolder 'deckbuilder-installer'
    try {
        $exe = Join-Path $work $asset.name
        Save-Download $asset $exe
        if ($DryRun) {
            Write-Note "Dry run: would run $exe"
            return 'dry run (downloaded and verified)'
        }
        Write-Host '    Running the Deckbuilder installer...'
        Write-Note 'If Windows says "Windows protected your PC": More info > Run anyway. Close Deckbuilder first if it is open.'
        $startArgs = @{ FilePath = $exe; Wait = $true; PassThru = $true }
        if ($SilentDeckbuilder) { $startArgs['ArgumentList'] = '/S' }
        $process = Start-Process @startArgs
        if ($process.ExitCode -ne 0) { throw "Deckbuilder's installer reported an error (exit code $($process.ExitCode))." }
        Write-Ok "Deckbuilder v$latest installed."
        return "installed v$latest"
    } finally {
        Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --------------------------------------------------------------------- main

function Read-AppChoice {
    Write-Host ''
    Write-Host 'Which would you like to install or update?'
    Write-Host '  1) Pawmodoro    - notes, checklist and pomodoro timer'
    Write-Host '  2) Deckbuilder  - trading card deckbuilder'
    Write-Host '  3) Both'
    $answer = (Read-Host 'Choice [3]').Trim()
    switch ($answer) {
        '1' { return 'Pawmodoro' }
        '2' { return 'Deckbuilder' }
        default { return 'Both' }
    }
}

function Main {
    Write-Host 'Pawmodoro / Deckbuilder installer' -ForegroundColor Cyan
    if ($DryRun) { Write-Note 'DRY RUN: nothing will be installed.' }
    $choice = $App
    if ($choice -eq 'Ask') { $choice = Read-AppChoice }

    $jobs = @()
    if ($choice -eq 'Both' -or $choice -eq 'Pawmodoro') { $jobs += 'Pawmodoro' }
    if ($choice -eq 'Both' -or $choice -eq 'Deckbuilder') { $jobs += 'Deckbuilder' }

    $summary = @()
    $failed = $false
    foreach ($job in $jobs) {
        try {
            if ($job -eq 'Pawmodoro') { $outcome = Install-Pawmodoro } else { $outcome = Install-Deckbuilder }
            $summary += [pscustomobject]@{ App = $job; Result = $outcome }
        } catch {
            $failed = $true
            Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
            $summary += [pscustomobject]@{ App = $job; Result = 'FAILED' }
        }
    }

    Write-Step 'Summary'
    $summary | Format-Table -AutoSize | Out-String | Write-Host
    if ($failed) { Write-Host 'Something didn''t work; the messages above say what. You can run this again any time.' -ForegroundColor Red }
    if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
    return (-not $failed)
}

# Run unless the file was dot-sourced (which is how it is tested).
if ($MyInvocation.InvocationName -ne '.') {
    $succeeded = Main
    if (-not $succeeded) { exit 1 }
}
