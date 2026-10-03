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
        throw "Godot not found. Set GODOT_BIN to the Godot console executable."
    }

    $GodotBin = $godot.Source
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$passPattern = '^MicroC0re smoke PASS \|'
$failurePattern = '(?i)(SCRIPT ERROR:|ERROR:|FATAL:|Parse Error:|Compile Error:|Failed to load script|Could not preload resource|Invalid preload)'

# Buffer the complete Godot output before printing it. This prevents a PASS
# emitted by the smoke script from being surfaced when Godot logged a parser,
# compile, preload/load or runtime error earlier in the same process.
$rawOutput = @(
    & $GodotBin --headless --path $repoRoot --script "res://tests/smoke_test.gd" 2>&1 |
        ForEach-Object { "$_" }
)
$godotExitCode = $LASTEXITCODE

$hasGodotError = $false
foreach ($line in $rawOutput) {
    if ($line -match $failurePattern) {
        $hasGodotError = $true
        break
    }
}

$hasPass = @($rawOutput | Where-Object { $_ -match $passPattern }).Count -gt 0
$failed = ($godotExitCode -ne 0) -or $hasGodotError -or (-not $hasPass)

if ($failed) {
    foreach ($line in $rawOutput) {
        if ($line -notmatch $passPattern) {
            Write-Host $line
        }
    }

    Write-Host (
        "MicroC0re smoke FAIL | exit={0} godot_error={1} pass_seen={2}" -f
        $godotExitCode,
        $hasGodotError,
        $hasPass
    )
    exit 1
}

$rawOutput | ForEach-Object { Write-Host $_ }
exit 0
