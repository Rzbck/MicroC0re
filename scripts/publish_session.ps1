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
if ([int]$raw.schema -notin @(1, 2)) {
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
        capacity_protozoa = I $s.capacity_protozoa
        capacity_ciliates = I $s.capacity_ciliates
        capacity_flagellates = I $s.capacity_flagellates
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
        ecotypes = I $s.ecotypes
        species = I $s.species
        species_bacteria = I $s.species_bacteria
        species_protozoa = I $s.species_protozoa
        species_ciliates = I $s.species_ciliates
        species_flagellates = I $s.species_flagellates
        species_algae = I $s.species_algae
        species_decomposers = I $s.species_decomposers
        species_hyphae = I $s.species_hyphae
        biome_producer = I $s.biome_producer
        biome_biofilm = I $s.biome_biofilm
        biome_detrital = I $s.biome_detrital
        biome_fungal = I $s.biome_fungal
        biome_anoxic = I $s.biome_anoxic
        biome_disturbed = I $s.biome_disturbed
        biome_recently_modified = I $s.biome_recently_modified
        biome_transitions = I $s.biome_transitions
        lineage_bins = I $s.lineage_bins
        max_generation = I $s.max_generation
        structural_mutations = I $s.structural_mutations
        hgt_events = I $s.hgt_events
        transformations = I $s.transformations
        capability_mix_events = I $s.capability_mix_events
        refugia_recoveries = I $s.refugia_recoveries
        zoom = [Math]::Round((N $s.zoom), 3)
        rotation = I $s.rotation
        seed = I $s.seed
    }
}

$safeLongSamples = @()
$hasLongSamples = (
    ([int]$raw.schema -ge 2) -and
    ($null -ne $raw.PSObject.Properties["long_samples"]) -and
    ($null -ne $raw.long_samples)
)
if ($hasLongSamples) {
foreach ($s in @($raw.long_samples)) {
    if ($null -eq $s) { continue }
    $e = $s.events
    $safeLongSamples += [ordered]@{
        t_s = I $s.t_s
        agents = I $s.agents
        bacteria = I $s.bacteria
        protozoa = I $s.protozoa
        ciliates = I $s.ciliates
        flagellates = I $s.flagellates
        capacity_protozoa = I $s.capacity_protozoa
        capacity_ciliates = I $s.capacity_ciliates
        capacity_flagellates = I $s.capacity_flagellates
        algae = I $s.algae
        decomposers = I $s.decomposers
        hyphae = I $s.hyphae
        actual_speed = [Math]::Round((N $s.actual_speed), 3)
        soil_excavated = [Math]::Round((N $s.soil_excavated), 3)
        soil_deposited = [Math]::Round((N $s.soil_deposited), 3)
        ecotypes = I $s.ecotypes
        species = I $s.species
        species_bacteria = I $s.species_bacteria
        species_protozoa = I $s.species_protozoa
        species_ciliates = I $s.species_ciliates
        species_flagellates = I $s.species_flagellates
        species_algae = I $s.species_algae
        species_decomposers = I $s.species_decomposers
        species_hyphae = I $s.species_hyphae
        biome_producer = I $s.biome_producer
        biome_biofilm = I $s.biome_biofilm
        biome_detrital = I $s.biome_detrital
        biome_fungal = I $s.biome_fungal
        biome_anoxic = I $s.biome_anoxic
        biome_disturbed = I $s.biome_disturbed
        biome_recently_modified = I $s.biome_recently_modified
        biome_transitions = I $s.biome_transitions
        lineage_bins = I $s.lineage_bins
        max_generation = I $s.max_generation
        structural_mutations = I $s.structural_mutations
        hgt_events = I $s.hgt_events
        transformations = I $s.transformations
        capability_mix_events = I $s.capability_mix_events
        refugia_recoveries = I $s.refugia_recoveries
        events = [ordered]@{
            pred_proto_bacteria = I $e.pred_proto_bacteria
            pred_proto_ciliate = I $e.pred_proto_ciliate
            pred_proto_flagellate = I $e.pred_proto_flagellate
            pred_proto_algae = I $e.pred_proto_algae
            pred_proto_decomposer = I $e.pred_proto_decomposer
            pred_ciliate_bacteria = I $e.pred_ciliate_bacteria
            pred_ciliate_flagellate = I $e.pred_ciliate_flagellate
            pred_ciliate_algae = I $e.pred_ciliate_algae
            pred_ciliate_decomposer = I $e.pred_ciliate_decomposer
            pred_flagellate_bacteria = I $e.pred_flagellate_bacteria
            escape_proto = I $e.escape_proto
            escape_ciliate = I $e.escape_ciliate
            escape_flagellate = I $e.escape_flagellate
            repro_bacteria = I $e.repro_bacteria
            repro_protozoa = I $e.repro_protozoa
            repro_ciliates = I $e.repro_ciliates
            repro_flagellates = I $e.repro_flagellates
            repro_algae = I $e.repro_algae
            repro_decomposers = I $e.repro_decomposers
            repro_hyphae = I $e.repro_hyphae
            refugia_bacteria = I $e.refugia_bacteria
            refugia_protozoa = I $e.refugia_protozoa
            refugia_ciliates = I $e.refugia_ciliates
            refugia_flagellates = I $e.refugia_flagellates
            refugia_algae = I $e.refugia_algae
            refugia_decomposers = I $e.refugia_decomposers
            refugia_hyphae = I $e.refugia_hyphae
            disturbance_resource = I $e.disturbance_resource
            disturbance_washout = I $e.disturbance_washout
            disturbance_organic = I $e.disturbance_organic
        }
    }
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
$ecotypeValues = @($safeSamples | ForEach-Object { [double]$_.ecotypes })
$speciesValues = @($safeSamples | ForEach-Object { [double]$_.species })
$generationValues = @($safeSamples | ForEach-Object { [double]$_.max_generation })
$structuralValues = @($safeSamples | ForEach-Object { [double]$_.structural_mutations })
$hgtValues = @($safeSamples | ForEach-Object { [double]$_.hgt_events })
$refugiaValues = @($safeSamples | ForEach-Object { [double]$_.refugia_recoveries })

$counters = [ordered]@{
    rotations = I $raw.counters.rotations
    zooms = I $raw.counters.zooms
    selection_attempts = I $raw.counters.selection_attempts
    selection_hits = I $raw.counters.selection_hits
    menu_opens = I $raw.counters.menu_opens
    seed_changes = I $raw.counters.seed_changes
}

$safe = [ordered]@{
    schema = I $raw.schema
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

$historySamples = if ($safeLongSamples.Count -gt 0) { $safeLongSamples } else { $safeSamples }
$historyFirst = if ($historySamples.Count -gt 0) { $historySamples[0] } else { $null }
$historyLast = if ($historySamples.Count -gt 0) { $historySamples[$historySamples.Count - 1] } else { $null }
$historyStart = if ($null -ne $historyFirst) { I $historyFirst.t_s } else { 0 }
$historyEnd = if ($null -ne $historyLast) { I $historyLast.t_s } else { 0 }
$historyCoverage = [Math]::Max(0, $historyEnd - $historyStart)

function EventValue([object]$Sample, [string]$Name) {
    if ($null -eq $Sample -or $null -eq $Sample.events) { return 0 }
    return I $Sample.events.$Name
}

function PredProto([object]$Sample) {
    return (EventValue $Sample "pred_proto_bacteria") +
        (EventValue $Sample "pred_proto_ciliate") +
        (EventValue $Sample "pred_proto_flagellate") +
        (EventValue $Sample "pred_proto_algae") +
        (EventValue $Sample "pred_proto_decomposer")
}

function PredCiliate([object]$Sample) {
    return (EventValue $Sample "pred_ciliate_bacteria") +
        (EventValue $Sample "pred_ciliate_flagellate") +
        (EventValue $Sample "pred_ciliate_algae") +
        (EventValue $Sample "pred_ciliate_decomposer")
}

function PredFlagellate([object]$Sample) {
    return (EventValue $Sample "pred_flagellate_bacteria")
}

function EscapeTotal([object]$Sample) {
    return (EventValue $Sample "escape_proto") +
        (EventValue $Sample "escape_ciliate") +
        (EventValue $Sample "escape_flagellate")
}

$firstSample = if ($safeSamples.Count -gt 0) { $safeSamples[0] } else { $null }
$lastSample = if ($safeSamples.Count -gt 0) { $safeSamples[$safeSamples.Count - 1] } else { $null }
$retainedStart = if ($null -ne $firstSample) { I $firstSample.t_s } else { 0 }
$retainedEnd = if ($null -ne $lastSample) { I $lastSample.t_s } else { 0 }
$retainedCoverage = [Math]::Max(0, $retainedEnd - $retainedStart)

function FinalValue([string]$Name) {
    if ($null -eq $lastSample) { return 0 }
    return I $lastSample.$Name
}

$timelineLines = New-Object System.Collections.Generic.List[string]
$timelineLines.Add("t_s bac pro cil fla alg dec hyp eco gen mut hgt ref predP predC predF esc rB rP rC rF rA rD rH soilE soilD speed")
if ($historySamples.Count -gt 0) {
    $stride = [Math]::Max(1, [int][Math]::Ceiling($historySamples.Count / 180.0))
    for ($i = 0; $i -lt $historySamples.Count; $i += $stride) {
        $s = $historySamples[$i]
        $timelineLines.Add((
            "{0} {1} {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13} {14} {15} {16} {17} {18} {19} {20} {21} {22} {23} {24:N1} {25:N1} {26:N2}" -f
            (I $s.t_s),(I $s.bacteria),(I $s.protozoa),(I $s.ciliates),(I $s.flagellates),
            (I $s.algae),(I $s.decomposers),(I $s.hyphae),(I $s.ecotypes),(I $s.max_generation),
            (I $s.structural_mutations),(I $s.hgt_events),(I $s.refugia_recoveries),
            (PredProto $s),(PredCiliate $s),(PredFlagellate $s),(EscapeTotal $s),
            (EventValue $s "repro_bacteria"),(EventValue $s "repro_protozoa"),
            (EventValue $s "repro_ciliates"),(EventValue $s "repro_flagellates"),
            (EventValue $s "repro_algae"),(EventValue $s "repro_decomposers"),
            (EventValue $s "repro_hyphae"),(N $s.soil_excavated),(N $s.soil_deposited),
            (N $s.actual_speed)
        ))
    }
    $lastIndex = $historySamples.Count - 1
    if (($lastIndex % $stride) -ne 0) {
        $s = $historySamples[$lastIndex]
        $timelineLines.Add((
            "{0} {1} {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13} {14} {15} {16} {17} {18} {19} {20} {21} {22} {23} {24:N1} {25:N1} {26:N2}" -f
            (I $s.t_s),(I $s.bacteria),(I $s.protozoa),(I $s.ciliates),(I $s.flagellates),
            (I $s.algae),(I $s.decomposers),(I $s.hyphae),(I $s.ecotypes),(I $s.max_generation),
            (I $s.structural_mutations),(I $s.hgt_events),(I $s.refugia_recoveries),
            (PredProto $s),(PredCiliate $s),(PredFlagellate $s),(EscapeTotal $s),
            (EventValue $s "repro_bacteria"),(EventValue $s "repro_protozoa"),
            (EventValue $s "repro_ciliates"),(EventValue $s "repro_flagellates"),
            (EventValue $s "repro_algae"),(EventValue $s "repro_decomposers"),
            (EventValue $s "repro_hyphae"),(N $s.soil_excavated),(N $s.soil_deposited),
            (N $s.actual_speed)
        ))
    }
}
$timelineText = $timelineLines -join [Environment]::NewLine

$diversityLines = New-Object System.Collections.Generic.List[string]
$diversityLines.Add("t_s species bSp pSp cSp fSp aSp dSp hSp bioP bioB bioD bioF bioA bioX bioT")
if ($historySamples.Count -gt 0) {
    $divStride = [Math]::Max(1, [int][Math]::Ceiling($historySamples.Count / 180.0))
    for ($i = 0; $i -lt $historySamples.Count; $i += $divStride) {
        $s = $historySamples[$i]
        $diversityLines.Add((
            "{0} {1} {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13} {14} {15}" -f
            (I $s.t_s),(I $s.species),(I $s.species_bacteria),(I $s.species_protozoa),
            (I $s.species_ciliates),(I $s.species_flagellates),(I $s.species_algae),
            (I $s.species_decomposers),(I $s.species_hyphae),(I $s.biome_producer),
            (I $s.biome_biofilm),(I $s.biome_detrital),(I $s.biome_fungal),
            (I $s.biome_anoxic),(I $s.biome_disturbed),(I $s.biome_transitions)
        ))
    }
    $lastIndex = $historySamples.Count - 1
    if (($lastIndex % $divStride) -ne 0) {
        $s = $historySamples[$lastIndex]
        $diversityLines.Add((
            "{0} {1} {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13} {14} {15}" -f
            (I $s.t_s),(I $s.species),(I $s.species_bacteria),(I $s.species_protozoa),
            (I $s.species_ciliates),(I $s.species_flagellates),(I $s.species_algae),
            (I $s.species_decomposers),(I $s.species_hyphae),(I $s.biome_producer),
            (I $s.biome_biofilm),(I $s.biome_detrital),(I $s.biome_fungal),
            (I $s.biome_anoxic),(I $s.biome_disturbed),(I $s.biome_transitions)
        ))
    }
}
$diversityText = $diversityLines -join [Environment]::NewLine

$trophicLines = New-Object System.Collections.Generic.List[string]
$trophicLines.Add("t_s proto/pCap cil/cCap fla/fCap recentModified")
if ($historySamples.Count -gt 0) {
    $trophicStride = [Math]::Max(1, [int][Math]::Ceiling($historySamples.Count / 120.0))
    for ($i = 0; $i -lt $historySamples.Count; $i += $trophicStride) {
        $s = $historySamples[$i]
        $trophicLines.Add((
            "{0} {1}/{2} {3}/{4} {5}/{6} {7}" -f
            (I $s.t_s),(I $s.protozoa),(I $s.capacity_protozoa),
            (I $s.ciliates),(I $s.capacity_ciliates),
            (I $s.flagellates),(I $s.capacity_flagellates),
            (I $s.biome_recently_modified)
        ))
    }
}
$trophicText = $trophicLines -join [Environment]::NewLine

$summary = @"
### Session $sessionId

Build ``$buildSha`` · Godot ``$godot`` · $osFamily · $gpuVendor · $renderer · $displayBucket  
Duration: $($safe.duration_s)s · retained detailed window: $retainedStart s → $retainedEnd s ($([Math]::Round($retainedCoverage / 60.0, 1)) min) · samples: $($safeSamples.Count)  
Ecological history: $historyStart s → $historyEnd s ($([Math]::Round($historyCoverage / 3600.0, 2)) h) · long samples: $($safeLongSamples.Count)

> Schema 1 sessions retain only the final ~30 minutes in detail. Schema 2 additionally records a one-minute ecological history for up to 7 days.

| performance | p50 | p95 | max/min |
| --- | ---: | ---: | ---: |
| frame max ms | $([Math]::Round((Percentile $frameValues 0.50),2)) | $([Math]::Round((Percentile $frameValues 0.95),2)) | $([Math]::Round((Percentile $frameValues 1.0),2)) |
| sim step ms | $([Math]::Round((Percentile $simValues 0.50),2)) | $([Math]::Round((Percentile $simValues 0.95),2)) | $([Math]::Round((Percentile $simValues 1.0),2)) |
| core sim ms | $([Math]::Round((Percentile $coreValues 0.50),2)) | $([Math]::Round((Percentile $coreValues 0.95),2)) | $([Math]::Round((Percentile $coreValues 1.0),2)) |
| terrain agents ms | $([Math]::Round((Percentile $terrainSimValues 0.50),2)) | $([Math]::Round((Percentile $terrainSimValues 0.95),2)) | $([Math]::Round((Percentile $terrainSimValues 1.0),2)) |
| FPS | $([Math]::Round((Percentile $fpsValues 0.50),1)) | — | $([Math]::Round((Percentile $fpsValues 0.0),1)) min |
| achieved speed | $([Math]::Round((Percentile $actualSpeedValues 0.50),2)) | $([Math]::Round((Percentile $actualSpeedValues 0.95),2)) | $([Math]::Round((Percentile $actualSpeedValues 1.0),2)) |

| guild | min | max | final |
| --- | ---: | ---: | ---: |
| bacteria | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.bacteria }) 0.0),0)) | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.bacteria }) 1.0),0)) | $(FinalValue "bacteria") |
| protozoa | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.protozoa }) 0.0),0)) | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.protozoa }) 1.0),0)) | $(FinalValue "protozoa") |
| ciliates | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.ciliates }) 0.0),0)) | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.ciliates }) 1.0),0)) | $(FinalValue "ciliates") |
| flagellates | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.flagellates }) 0.0),0)) | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.flagellates }) 1.0),0)) | $(FinalValue "flagellates") |
| algae | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.algae }) 0.0),0)) | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.algae }) 1.0),0)) | $(FinalValue "algae") |
| decomposers | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.decomposers }) 0.0),0)) | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.decomposers }) 1.0),0)) | $(FinalValue "decomposers") |
| hyphae | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.hyphae }) 0.0),0)) | $([Math]::Round((Percentile @($safeSamples | ForEach-Object { [double]$_.hyphae }) 1.0),0)) | $(FinalValue "hyphae") |

Evolution final/peak: species $(FinalValue "species")/$([Math]::Round((Percentile $speciesValues 1.0),0)), ecotypes $(FinalValue "ecotypes")/$([Math]::Round((Percentile $ecotypeValues 1.0),0)), lineage bins $(FinalValue "lineage_bins"), generation $(FinalValue "max_generation")/$([Math]::Round((Percentile $generationValues 1.0),0)), structural mutations $(FinalValue "structural_mutations")/$([Math]::Round((Percentile $structuralValues 1.0),0)), HGT $(FinalValue "hgt_events")/$([Math]::Round((Percentile $hgtValues 1.0),0)), transformations $(FinalValue "transformations"), capability mixes $(FinalValue "capability_mix_events"), refugia recoveries $(FinalValue "refugia_recoveries").  
Terraforming final: excavated $([Math]::Round((N $lastSample.soil_excavated),2)), deposited $([Math]::Round((N $lastSample.soil_deposited),2)).  
Biome final: producer $(FinalValue "biome_producer"), biofilm $(FinalValue "biome_biofilm"), detrital $(FinalValue "biome_detrital"), fungal $(FinalValue "biome_fungal"), anoxic $(FinalValue "biome_anoxic"), disturbed $(FinalValue "biome_disturbed"), recently modified $(FinalValue "biome_recently_modified"), transitions $(FinalValue "biome_transitions").  
Trophic final: protozoa $(FinalValue "protozoa")/$(FinalValue "capacity_protozoa"), ciliates $(FinalValue "ciliates")/$(FinalValue "capacity_ciliates"), flagellates $(FinalValue "flagellates")/$(FinalValue "capacity_flagellates").  
Interactions final: proto predation $(PredProto $historyLast), ciliate predation $(PredCiliate $historyLast), flagellate predation $(PredFlagellate $historyLast), prey escapes $(EscapeTotal $historyLast).  
Reproduction final: bacteria $(EventValue $historyLast "repro_bacteria"), protozoa $(EventValue $historyLast "repro_protozoa"), ciliates $(EventValue $historyLast "repro_ciliates"), flagellates $(EventValue $historyLast "repro_flagellates"), algae $(EventValue $historyLast "repro_algae"), decomposers $(EventValue $historyLast "repro_decomposers"), hyphae $(EventValue $historyLast "repro_hyphae").  
Inputs: rotations $($counters.rotations), zooms $($counters.zooms), selections $($counters.selection_hits)/$($counters.selection_attempts), menu opens $($counters.menu_opens).

<details>
<summary>Compact ecological timeline (full long history when schema 2; ≤180 rows)</summary>

```text
$timelineText
```

</details>

<details>
<summary>Species and biome succession timeline (≤180 rows)</summary>

```text
$diversityText
```

</details>

<details>
<summary>Predator carrying-capacity timeline (≤120 rows)</summary>

```text
$trophicText
```

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
