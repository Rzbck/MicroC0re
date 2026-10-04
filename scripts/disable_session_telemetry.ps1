$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$flag = Join-Path $repoRoot ".microcore\telemetry-opt-in"
Remove-Item $flag -Force -ErrorAction SilentlyContinue
Write-Host "Telemetry publishing disabled. Local performance reports remain enabled."
