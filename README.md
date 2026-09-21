# Deckbuilder — downloads

Desktop deckbuilder for **Riftbound, One Piece Card Game, Pokémon TCG and Magic: The Gathering**: card browser, legality checks (including Commander), collection and wishlist tracking, a full-screen deck view, and export. This repo only hosts the downloadable installers.

## Download

| | |
|---|---|
| **Windows** | [Deckbuilder-Setup.exe](https://github.com/beeftcg-eng/deckbuilder-releases/releases/latest/download/Deckbuilder-Setup.exe) — always the newest version |
| **Linux** | [Deckbuilder.AppImage](https://github.com/beeftcg-eng/deckbuilder-releases/releases/latest/download/Deckbuilder.AppImage) — `chmod +x` it, then run it |
| Everything else | the [latest release](../../releases/latest) page |

Windows may show a blue "Windows protected your PC" screen because the installer isn't code-signed. Click **More info → Run anyway**.

**From PowerShell** (downloads the newest installer and runs it):

```powershell
$f = Join-Path $env:TEMP 'Deckbuilder-Setup.exe'
$ProgressPreference = 'SilentlyContinue'   # otherwise Windows PowerShell downloads very slowly
Invoke-WebRequest 'https://github.com/beeftcg-eng/deckbuilder-releases/releases/latest/download/Deckbuilder-Setup.exe' -OutFile $f
Start-Process $f -Wait
```

## Install or update both apps with one script (Windows)

[`Install-Pawmodoro-and-Deckbuilder.ps1`](Install-Pawmodoro-and-Deckbuilder.ps1) downloads the newest **Pawmodoro** and/or **Deckbuilder**, checks each download against the checksum GitHub lists for it, and runs the app's own installer. It asks which you want, skips anything already up to date, and is safe to run again. (Pawmodoro needs Python 3 from [python.org](https://www.python.org/downloads/) — tick "Add python.exe to PATH" — or the Microsoft Store; the script tells you if it's missing.)

**Easiest — no typing or pasting:** open [`Install-Pawmodoro-and-Deckbuilder.bat`](https://github.com/beeftcg-eng/deckbuilder-releases/blob/main/Install-Pawmodoro-and-Deckbuilder.bat), click the **download** icon at the top right of the file ("Download raw file"), then double-click the downloaded file. It fetches the newest script and runs it. If Windows says "Windows protected your PC", click **More info → Run anyway** (the file isn't code-signed).

**Or paste this into PowerShell** (copy just the three lines, with nothing in front of them):

```powershell
$s = Join-Path $env:TEMP 'Install-Pawmodoro-and-Deckbuilder.ps1'
Invoke-WebRequest 'https://raw.githubusercontent.com/beeftcg-eng/deckbuilder-releases/main/Install-Pawmodoro-and-Deckbuilder.ps1' -OutFile $s -UseBasicParsing
powershell -ExecutionPolicy Bypass -File $s
```

Or download the file yourself and run `powershell -ExecutionPolicy Bypass -File .\Install-Pawmodoro-and-Deckbuilder.ps1` (if Windows blocks it because it came from the internet, run `Unblock-File` on it first). Options: `-App Pawmodoro` / `-App Deckbuilder` to skip the question, `-Force` to reinstall, `-SilentDeckbuilder`, and `-DryRun` to download and verify without installing. The script is short and readable — open it and see exactly what it does before you run it.

## Updates

From version 0.7.0 the app **updates itself**: a few seconds after launch (and every 6 hours while it's open) it checks this repo, downloads a newer version in the background, and shows a **Restart & update** banner. If you ignore the banner it installs the next time you close the app. The sidebar shows your version and a **Check for updates** link. (On Linux, updating works for the AppImage.)

If you have 0.6.0 or older there's no updater yet: install the latest version once by hand, using the links above, and it takes care of itself from then on. Your decks, wishlist and collection are stored separately from the app and are kept.

## First launch

Pick a game in the sidebar and click **Sync card data** (Pokémon has ~20k cards and Magic ~32k; each takes a few minutes at most). To send wishlist cards to your Pawmodoro checklist, open the Wishlist panel and create an account with an email and password — it's already connected to the shared Pawmodoro cloud.
