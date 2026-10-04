param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
$repo = "Rzbck/MicroC0re"
$issue = 66

if (-not (Test-Path $ReportPath)) {
    throw "Session report not found."
}

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    throw "GitHub CLI (gh) is not installed."
}

& $gh.Source auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not authenticated."
}

$raw = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json
if ([int]$raw.schema -ne 1) {
    throw "Unsupported session telemetry schema."
}

function Safe-Token([string]$Value, [string]$Pattern, [string]$Fallback) {
    if ($Value -match $Pattern) { return $Value }
    return $Fallback
}

function N([object]$Value) {
    if ($null -eq $Value) { return 0.0 }
    return [double]$Value
}

function I([object]$Value) {
    if ($null -eq $Value) { return 0 }
    return [int]$Value
}

function Percentile([double[]]$Values, [double]$P) {
    if (-not $Values -or $Values.Count -eq 0) { return 0.0 }
    $sorted = $Values | Sort-Object
    $index = [Math]::Floor(($sorted.Count - 1) * $P)
    return [double]$sorted[$index]
}

$sessionId = Safe-Token ([string]$raw.session_id) '^[0-9a-f]{16}$' 'unknown'
$buildSha = Safe-Token ([string]$raw.build_sha) '^(unknown|[0-9a-f]{7,40})$' 'unknown'
$godot = Safe-Token ([string]$raw.godot) '^[0-9A-Za-z.+ _-]{1,40}$' 'unknown'
$osFamily = Safe-Token ([string]$raw.os_family) '^(windows|linux|macos|other)$' 'other'
$gpuVendor = Safe-Token ([string]$raw.gpu_vendor) '^(nvidia|amd|intel|apple|other)$' 'other'
$renderer = Safe-Token ([string]$raw.renderer) '^(forward_plus|mobile|gl_compatibility|other)$' 'other'
$displayBucket = Safe-Token ([string]$raw.display_bucket) '^(720p|1080p|1440p|4k|headless|other)$' 'other'

$safeSamples = @()
foreach ($s in @($raw.samples)) {
    $safeSamples += [ordered]@{
        t_s = I $s.t_s
        fps = [Math]::Round((N $s.fps), 1)
        frame_ms_avg = [Math]::Round((N $s.frame_ms_avg), 3)
        frame_ms_max = [Math]::Round((N $s.frame_ms_max), 3)
        process_ms = [Math]::Round((N $s.process_ms), 3)
        sim_ms = [Math]::Round((N $s.sim_ms), 3)
        core_sim_ms = [Math]::Round((N $s.core_sim_ms), 3)
        terrain_sim_ms = [Math]::Round((N $s.terrain_sim_ms), 3)
        chemistry_ms = [Math]::Round((N $s.chemistry_ms), 3)
        bacteria_agents_ms = [Math]::Round((N $s.bacteria_agents_ms), 3)
        mechanics_ms = [Math]::Round((N $s.mechanics_ms), 3)
        pair_candidates = I $s.pair_candidates
        pair_narrow = I $s.pair_narrow
        pair_contacts = I $s.pair_contacts
        mechanics_mode = I $s.mechanics_mode
        draw_ms = [Math]::Round((N $s.draw_ms), 3)
        terrain_build_ms = [Math]::Round((N $s.terrain_build_ms), 3)
        draw_calls = I $s.draw_calls
        agents = I $s.agents
        bacteria = I $s.bacteria
        protozoa = I $s.protozoa
        ciliates = I $s.ciliates
        flagellates = I $s.flagellates
        algae = I $s.algae
        decomposers = I $s.decomposers
        hyphae = I $s.hyphae
        visible_tiles = I $s.visible_tiles
        terrain_triangles = I $s.terrain_triangles
        far_agent_count = I $s.far_agent_count
        requested_speed = [Math]::Round((N $s.requested_speed), 3)
        actual_speed = [Math]::Round((N $s.actual_speed), 3)
        terrain_revision = I $s.terrain_revision
        soil_excavated = [Math]::Round((N $s.soil_excavated), 3)
        soil_deposited = [Math]::Round((N $s.soil_deposited), 3)
        capability_fragments = I $s.capability_fragments
        zoom = [Math]::Round((N $s.zoom), 3)
        rotation = I $s.rotation
        seed = I $s.seed
    }
}

$frameValues = @($safeSamples | ForEach-Object { [double]$_.frame_ms_max })
$simValues = @($safeSamples | ForEach-Object { [double]$_.sim_ms })
$coreValues = @($safeSamples | ForEach-Object { [double]$_.core_sim_ms })
$terrainSimValues = @($safeSamples | ForEach-Object { [double]$_.terrain_sim_ms })
$agentsValues = @($safeSamples | ForEach-Object { [double]$_.bacteria_agents_ms })
$mechanicsValues = @($safeSamples | ForEach-Object { [double]$_.mechanics_ms })
$drawValues = @($safeSamples | ForEach-Object { [double]$_.draw_ms })
$terrainBuildValues = @($safeSamples | ForEach-Object { [double]$_.terrain_build_ms })
$requestedSpeedValues = @($safeSamples | ForEach-Object { [double]$_.requested_speed })
$actualSpeedValues = @($safeSamples | ForEach-Object { [double]$_.actual_speed })
$fpsValues = @($safeSamples | ForEach-Object { [double]$_.fps })
$agentValues = @($safeSamples | ForEach-Object { [double]$_.agents })

$counters = [ordered]@{
    rotations = I $raw.counters.rotations
    zooms = I $raw.counters.zooms
    selection_attempts = I $raw.counters.selection_attempts
    selection_hits = I $raw.counters.selection_hits
    menu_opens = I $raw.counters.menu_opens
    seed_changes = I $raw.counters.seed_changes
}

$safe = [ordered]@{
    schema = 1
    session_id = $sessionId
    build_sha = $buildSha
    godot = $godot
    os_family = $osFamily
    gpu_vendor = $gpuVendor
    renderer = $renderer
    display_bucket = $displayBucket
    duration_s = I $raw.duration_s
    counters = $counters
    samples = $safeSamples
}

$summary = @"
### Session $sessionId

Build ``$buildSha`` · Godot ``$godot`` · $osFamily · $gpuVendor · $renderer · $displayBucket  
Duration: $($safe.duration_s)s · samples: $($safeSamples.Count) · agent max: $([Math]::Round((Percentile $agentValues 1.0),0))

| metric | p50 | p95 | max/min |
| --- | ---: | ---: | ---: |
| frame max ms | $([Math]::Round((Percentile $frameValues 0.50),2)) | $([Math]::Round((Percentile $frameValues 0.95),2)) | $([Math]::Round((Percentile $frameValues 1.0),2)) |
| sim step ms | $([Math]::Round((Percentile $simValues 0.50),2)) | $([Math]::Round((Percentile $simValues 0.95),2)) | $([Math]::Round((Percentile $simValues 1.0),2)) |
| core sim ms | $([Math]::Round((Percentile $coreValues 0.50),2)) | $([Math]::Round((Percentile $coreValues 0.95),2)) | $([Math]::Round((Percentile $coreValues 1.0),2)) |
| terrain agents ms | $([Math]::Round((Percentile $terrainSimValues 0.50),2)) | $([Math]::Round((Percentile $terrainSimValues 0.95),2)) | $([Math]::Round((Percentile $terrainSimValues 1.0),2)) |
| bacteria update ms | $([Math]::Round((Percentile $agentsValues 0.50),2)) | $([Math]::Round((Percentile $agentsValues 0.95),2)) | $([Math]::Round((Percentile $agentsValues 1.0),2)) |
| mechanics ms | $([Math]::Round((Percentile $mechanicsValues 0.50),2)) | $([Math]::Round((Percentile $mechanicsValues 0.95),2)) | $([Math]::Round((Percentile $mechanicsValues 1.0),2)) |
| draw ms | $([Math]::Round((Percentile $drawValues 0.50),2)) | $([Math]::Round((Percentile $drawValues 0.95),2)) | $([Math]::Round((Percentile $drawValues 1.0),2)) |
| terrain batch rebuild ms | $([Math]::Round((Percentile $terrainBuildValues 0.50),2)) | $([Math]::Round((Percentile $terrainBuildValues 0.95),2)) | $([Math]::Round((Percentile $terrainBuildValues 1.0),2)) |
| FPS | $([Math]::Round((Percentile $fpsValues 0.50),1)) | — | $([Math]::Round((Percentile $fpsValues 0.0),1)) min |
| requested speed | $([Math]::Round((Percentile $requestedSpeedValues 0.50),2)) | $([Math]::Round((Percentile $requestedSpeedValues 0.95),2)) | $([Math]::Round((Percentile $requestedSpeedValues 1.0),2)) |
| achieved speed | $([Math]::Round((Percentile $actualSpeedValues 0.50),2)) | $([Math]::Round((Percentile $actualSpeedValues 0.95),2)) | $([Math]::Round((Percentile $actualSpeedValues 1.0),2)) |

Inputs: rotations $($counters.rotations), zooms $($counters.zooms), selections $($counters.selection_hits)/$($counters.selection_attempts), menu opens $($counters.menu_opens).

<details>
<summary>Allowlisted 2-second samples</summary>

~~~json
$($safe | ConvertTo-Json -Depth 8 -Compress)
~~~

</details>
"@

$temp = [System.IO.Path]::GetTempFileName()
try {
    Set-Content -Path $temp -Value $summary -Encoding UTF8
    & $gh.Source issue comment $issue --repo $repo --body-file $temp
    if ($LASTEXITCODE -ne 0) {
        throw "gh issue comment failed."
    }
    Write-Host "Anonymous session report published to GitHub issue #$issue."
}
finally {
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
}
