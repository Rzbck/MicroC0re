param(
    [switch]$Yes
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$localDir = Join-Path $repoRoot ".microcore"
$flag = Join-Path $localDir "telemetry-opt-in"

Write-Host ""
Write-Host "MicroC0re anonymous session telemetry"
Write-Host "-----------------------------------"
Write-Host "Public GitHub reports contain only:"
Write-Host "- random per-session ID, public build SHA, seed"
Write-Host "- OS family, GPU vendor, renderer, coarse display bucket"
Write-Host "- bounded FPS/frame/simulation/draw/population/terrain samples"
Write-Host "- rotation/zoom/selection/menu counters"
Write-Host ""
Write-Host "They do NOT contain username, hostname, IP/MAC, paths, locale,"
Write-Host "precise location, exact GPU model, environment variables, or raw logs."
Write-Host ""

if (-not $Yes) {
    $answer = Read-Host "Type ENABLE to publish future session summaries to public issue #66"
    if ($answer -ne "ENABLE") {
        Write-Host "Telemetry publishing remains disabled."
        exit 0
    }
}

New-Item -ItemType Directory -Path $localDir -Force | Out-Null
Set-Content -Path $flag -Value "enabled" -Encoding ASCII
Write-Host "Telemetry publishing enabled for this checkout."
