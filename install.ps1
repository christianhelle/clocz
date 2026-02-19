$ErrorActionPreference = 'Stop'

$repo = "christianhelle/clocz"
$artifact = "clocz-windows-x86_64.zip"
$installDir = "$env:USERPROFILE\.local\bin"

Write-Host "Fetching latest release..."
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
$asset = $release.assets | Where-Object { $_.name -eq $artifact }

if (-not $asset) {
    Write-Error "Could not find release asset: $artifact"
    exit 1
}

$url = $asset.browser_download_url
$tmpFile = Join-Path $env:TEMP $artifact

Write-Host "Downloading $url..."
Invoke-WebRequest -Uri $url -OutFile $tmpFile

Write-Host "Installing to $installDir..."
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Expand-Archive -Path $tmpFile -DestinationPath $installDir -Force
Remove-Item $tmpFile -Force

# Add to user PATH if not already present
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
    Write-Host "Added $installDir to user PATH (restart your terminal to use)"
}

Write-Host "clocz installed to $installDir\clocz.exe"
