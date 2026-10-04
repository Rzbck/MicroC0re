param(
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $godot = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $godot) {
        $godot = Get-Command godot4 -ErrorAction SilentlyContinue
    }

    if (-not $godot) {
        throw "Godot not found. Set GODOT_BIN to the Godot executable."
    }

    $GodotBin = $godot.Source
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$localDir = Join-Path $repoRoot ".microcore"
$telemetryDir = Join-Path $localDir "telemetry"
$reportPath = Join-Path $telemetryDir "last-session.json"
$optInPath = Join-Path $localDir "telemetry-opt-in"

New-Item -ItemType Directory -Path $telemetryDir -Force | Out-Null

$env:MICROCORE_SESSION_REPORT = $reportPath

try {
    $env:MICROCORE_BUILD_SHA = (
        git -C $repoRoot rev-parse --short=12 HEAD
    ).Trim()
}
catch {
    $env:MICROCORE_BUILD_SHA = "unknown"
}

Write-Host "Launching MicroC0re..."
& $GodotBin --rendering-method forward_plus --rendering-driver vulkan --path $repoRoot
$gameExitCode = $LASTEXITCODE

if (Test-Path $optInPath) {
    try {
        & (Join-Path $PSScriptRoot "publish_session.ps1") -ReportPath $reportPath
    }
    catch {
        Write-Warning "Session telemetry was kept local; publish failed: $($_.Exception.Message)"
    }
}
elseif (Test-Path $reportPath) {
    Write-Host ""
    Write-Host "Anonymous performance report saved locally."
    Write-Host "To opt in to automatic public GitHub reports, run:"
    Write-Host "  .\scripts\enable_session_telemetry.ps1"
}

exit $gameExitCode
