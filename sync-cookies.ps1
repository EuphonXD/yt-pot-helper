<#
.SYNOPSIS
  Export YouTube cookies from a local browser and push them into beat-saber-video-tool.
.DESCRIPTION
  Requires the video tool to be running (default http://127.0.0.1:8770).
  Cookies are only POSTed to that local tool; the temp file is deleted afterwards.
.PARAMETER Browser
  firefox | edge | chrome | brave | opera | vivaldi | chromium
.PARAMETER ToolUrl
  Base URL of beat-saber-video-tool.
.PARAMETER CookiesFile
  Upload an existing Netscape cookies.txt instead of exporting from a browser.
.PARAMETER Ytdlp
  Path to yt-dlp.exe (auto-detected when omitted).
.PARAMETER KeepFile
  Keep the exported temp cookie file.
#>
[CmdletBinding()]
param(
  [string]$Browser = 'edge',
  [string]$ToolUrl = 'http://127.0.0.1:8770',
  [string]$CookiesFile = '',
  [string]$Ytdlp = '',
  [switch]$KeepFile
)
$ErrorActionPreference = 'Stop'
function Info($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }

$ToolUrl = $ToolUrl.TrimEnd('/')
try { $null = Invoke-WebRequest -Uri ($ToolUrl + '/api/status') -UseBasicParsing -TimeoutSec 5 }
catch { Die "beat-saber-video-tool is not reachable: $ToolUrl" }
Ok "tool reachable: $ToolUrl"

$tmp = ''
if ($CookiesFile) {
  if (-not (Test-Path -LiteralPath $CookiesFile)) { Die "cookies file not found: $CookiesFile" }
  $tmp = (Resolve-Path -LiteralPath $CookiesFile).Path
  Ok "using existing file: $tmp"
} else {
  if (-not $Ytdlp -or -not (Test-Path $Ytdlp)) {
    $cands = @((Join-Path $PSScriptRoot 'bin\yt-dlp.exe'), (Join-Path $PSScriptRoot 'yt-dlp.exe')) | Where-Object { Test-Path $_ }
    if ($cands) { $Ytdlp = $cands[0] }
  }
  if (-not $Ytdlp -or -not (Test-Path $Ytdlp)) { Die 'yt-dlp.exe not found. Put it in .\bin\yt-dlp.exe or pass -Ytdlp.' }
  $tmp = Join-Path $env:TEMP ('yt-cookies-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.txt')
  Info "exporting cookies from $Browser ..."
  & $Ytdlp --cookies-from-browser $Browser --cookies $tmp --skip-download --simulate --no-warnings 'https://www.youtube.com/watch?v=jNQXAC9IVRw' *> $null
  if (-not (Test-Path $tmp)) { Die 'cookie export failed (is the browser logged in to YouTube?)' }
}

$content = Get-Content -LiteralPath $tmp -Raw
if (-not $content -or $content.IndexOf([char]9) -lt 0) { Die 'not a valid cookies.txt (Netscape format, tab separated)' }
$lines = ($content -split '?
').Count
Ok ("cookies loaded: $lines lines")

$body = @{ content = $content } | ConvertTo-Json -Compress
try {
  $res = Invoke-RestMethod -Uri ($ToolUrl + '/api/cookies/import') -Method Post -ContentType 'application/json' -Body $body
  Ok 'pushed to beat-saber-video-tool'
} catch { Die ("push failed: " + $_.Exception.Message) }

try {
  $d = Invoke-RestMethod -Uri ($ToolUrl + '/api/cookies/detect') -Method Post -TimeoutSec 20
  Ok ('detect: ' + ($d | ConvertTo-Json -Compress))
} catch { Warn 'detect skipped' }

if (-not $KeepFile -and -not $CookiesFile) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
Ok 'done'
