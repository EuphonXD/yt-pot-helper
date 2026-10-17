<#
.SYNOPSIS
  Download, build and run a local YouTube PoToken provider (bgutil) for yt-dlp.
.DESCRIPTION
  This script does not bundle the upstream project; it downloads the latest
  release from GitHub and prepares a launcher + logon task.
#>
[CmdletBinding()]
param(
  [int]$Port = 4416,
  [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'yt-pot'),
  [switch]$NoTask
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Repo = 'Brainicism/bgutil-ytdlp-pot-provider'
$TaskName = 'BgutilPOT'
function Info($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }
$node = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
if (-not $node) { Die 'Node.js 18+ not found: https://nodejs.org/' }
$ver = (& $node -v) -replace '^v',''
if ([int]($ver.Split('.')[0]) -lt 18) { Die "Node.js $ver found, need 18+" }
Ok "Node.js $ver ($node)"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Info 'Fetching latest release ...'
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'yt-pot-helper' }
$asset = $rel.assets | Where-Object { $_.name -match '(zip|tar\.gz)$' } | Select-Object -First 1
if (-not $asset) { Die 'No release asset found.' }
$zip = Join-Path $InstallDir $asset.name
Info "Downloading $($asset.name) ..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
Ok "Downloaded $zip"
$src = Join-Path $InstallDir 'src'
if (Test-Path $src) { Remove-Item $src -Recurse -Force }
New-Item -ItemType Directory -Force -Path $src | Out-Null
if ($zip -match '\.zip$') { Expand-Archive -Path $zip -DestinationPath $src -Force } else { tar -xzf $zip -C $src }
$root = (Get-ChildItem $src -Directory | Select-Object -First 1).FullName
Ok "Extracted $root"
$main = Join-Path $root 'server/build/main.js'
if (-not (Test-Path $main)) {
  $server = Join-Path $root 'server'
  if (-not (Test-Path $server)) { Die "server/ not found" }
  Info 'Building server (npm ci + npm run build) ...'
  Push-Location $server
  try { & npm.cmd ci --omit=dev 2>&1 | Out-Host; & npm.cmd run build 2>&1 | Out-Host } finally { Pop-Location }
  if (-not (Test-Path $main)) { Die "Build failed: $main" }
}
Ok "server entry $main"
$bat = Join-Path $InstallDir 'start-pot.bat'
$nl = [Environment]::NewLine
$line = '@echo off' + $nl + '"' + $node + '" "' + $main + '" --port ' + $Port + $nl
[IO.File]::WriteAllText($bat, $line, [Text.Encoding]::ASCII)
Ok "launcher $bat"
if (-not $NoTask) {
  $action = New-ScheduledTaskAction -Execute $bat
  $trigger = New-ScheduledTaskTrigger -AtLogOn
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Force | Out-Null
  Start-ScheduledTask -TaskName $TaskName
  Ok "task $TaskName registered"
} else { Warn '-NoTask: skipped' }
Info 'Waiting for provider ...'
$ok = $false
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 1
  try { $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/ping" -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -eq 200) { $ok = $true; break } } catch { }
}
if ($ok) { Ok "Provider up: http://127.0.0.1:$Port/ping" } else { Warn "No answer on port $Port within 30s." }
