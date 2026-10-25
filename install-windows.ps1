# Installs the latest Kaiser release for the current user, with a Start menu
# entry. In PowerShell:
#   irm https://raw.githubusercontent.com/LarsGehrmann/Kaiser-decompile/main/install-windows.ps1 | iex
# Kaiser Classic instead of Remastered:
#   $env:KAISER_EDITION = 'Classic'; irm https://raw.githubusercontent.com/LarsGehrmann/Kaiser-decompile/main/install-windows.ps1 | iex
# A download by PowerShell carries no "from the internet" mark, so SmartScreen
# does not stop the game (it is not signed with a code-signing certificate).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repo = 'LarsGehrmann/Kaiser-decompile'
$edition = if ($env:KAISER_EDITION -eq 'Classic') { 'Classic' } else { 'Remastered' }
$release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
$asset = $release.assets | Where-Object { $_.name -like "Kaiser-$edition-*-Windows-x64.zip" } | Select-Object -First 1
if (-not $asset) { throw "No Windows download of Kaiser $edition found in the latest release." }
$programs = Join-Path $env:LOCALAPPDATA 'Programs'
$target = Join-Path $programs "Kaiser $edition"
$zip = Join-Path $env:TEMP $asset.name
Write-Host "Downloading $($asset.name) ..."
Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing
New-Item -ItemType Directory -Force -Path $programs | Out-Null
if (Test-Path $target) { Remove-Item $target -Recurse -Force }
Expand-Archive $zip -DestinationPath $programs -Force
Remove-Item $zip
Get-ChildItem $target -Recurse -File | Unblock-File
$exe = Join-Path $target "Kaiser $edition.exe"
$link = Join-Path ([Environment]::GetFolderPath('Programs')) "Kaiser $edition.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($link)
$shortcut.TargetPath = $exe
$shortcut.WorkingDirectory = $target
$shortcut.Save()
Write-Host "Installed: $target (Start menu: Kaiser $edition)"
Start-Process $exe -WorkingDirectory $target
