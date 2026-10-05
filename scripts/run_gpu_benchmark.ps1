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

# Compute shaders require a RenderingDevice renderer. Do NOT use --headless.
& $GodotBin --rendering-method forward_plus --rendering-driver vulkan --path $repoRoot --script "res://tests/gpu_compute_benchmark.gd"
exit $LASTEXITCODE
