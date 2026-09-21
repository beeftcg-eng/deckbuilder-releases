@echo off
rem ---------------------------------------------------------------------------
rem  Install-Pawmodoro-and-Deckbuilder.bat
rem
rem  Double-click this file to install or update Pawmodoro and/or Deckbuilder.
rem  It downloads the newest installer script from GitHub and runs it; the
rem  script asks which app you want, checks each download's checksum, and
rem  runs that app's own installer.
rem
rem  If Windows says "Windows protected your PC", click "More info" and then
rem  "Run anyway" (this file isn't code-signed). To read exactly what it does,
rem  open it in Notepad, or read the script it downloads:
rem  https://github.com/beeftcg-eng/deckbuilder-releases/blob/main/Install-Pawmodoro-and-Deckbuilder.ps1
rem ---------------------------------------------------------------------------
title Pawmodoro / Deckbuilder installer
echo.
echo Downloading the installer script...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest 'https://raw.githubusercontent.com/beeftcg-eng/deckbuilder-releases/main/Install-Pawmodoro-and-Deckbuilder.ps1' -OutFile (Join-Path $env:TEMP 'Install-Pawmodoro-and-Deckbuilder.ps1') -UseBasicParsing"
if errorlevel 1 goto download_failed

powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\Install-Pawmodoro-and-Deckbuilder.ps1"
exit /b %errorlevel%

:download_failed
echo.
echo Could not download the installer script. Check your internet connection and try again.
echo.
pause
exit /b 1
