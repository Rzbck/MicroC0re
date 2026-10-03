# Living biome design

MicroC0re is no longer just a population of cells on top of a nutrient texture. The active direction is a **spatial aquatic micro-ecosystem** where organisms both respond to and modify their environment.

## Design principle

The interesting state should emerge from feedback loops:

```
light / dissolved resources / oxygen / flow
                  ↓
          primary producers
                  ↓
 dissolved organic matter / biomass
           ↙              ↘
 heterotrophs            decomposers
       ↓                     ↓
 grazers / predators ← detritus / damage cues
       ↓                     ↓
     death ─────────────→ recycling
       ↑
 evolution / HGT / phenotype switching
```

There is no global fitness score and no scripted ecological winner.

## Why spatial structure matters

Microbial communities are strongly shaped by short interaction ranges, resource gradients, spatial refuges and niche construction. Spatial structure changes competition, cross-feeding, quorum sensing and evolutionary dynamics.

MicroC0re therefore treats environmental fields and local neighborhoods as first-class simulation state rather than decorative background.

## Current biome fields

### Nutrient

Existing dissolved-resource field used by heterotrophic growth.

### Oxygen

Dynamic diffusing oxygen.

Current effects:
- aerobic energy yield depends partly on local oxygen;
- producer mats and phototrophic ecotypes release oxygen;
- oxygen diffuses and decays.

Future:
- explicit anaerobic guilds;
- redox interfaces;
- diel oxygen oscillation.

### Producer biomass

A coarse continuum representation of cyanobacteria/microalgal microbial mats.

Current behavior:
- biomass is seeded in spatial patches;
- light supports growth;
- active biomass releases oxygen;
- a small dissolved-organic leak feeds the microbial loop.

This continuum field now coexists with explicit individual microalgae-like producer organisms from #40.

### Detritus / carrion

Dead biomass and feeding leakage enter a detritus field instead of disappearing.

Current consumers:
- scavenger bacterial ecotype;
- bacteria carrying the mobile scavenge module.

Current additional consumer:
- explicit yeast-like decomposer organisms that consume detritus and mineralize part of it back into dissolved resource.

Future:
- extracellular enzyme breakdown;
- polymer substrate classes;
- particulate aggregates;
- filamentous hyphae.

### EPS / biofilm matrix

Cells with a biofilm-like phenotype or high adhesion secrete EPS at an energy cost.

Current effects:
- EPS persists spatially;
- high local EPS slows bacterial movement;
- secretion changes the environment.

Future:
- nutrient retention;
- flow reduction;
- predator refuge;
- quorum-controlled secretion;
- cooperative/cheater dynamics.

### Damage / lysis cue

Death, lysis and active predation emit a short-lived diffusing cue.

This represents a generic mixture of soluble material released from damaged cells: amino acids, organic acids and other chemoeffectors. It is intentionally **not called blood** in the aquatic biome.

Current effects:
- scavenger bacteria bias run-and-tumble sensing toward detritus/damage;
- amoebae and ciliates without directly visible prey bias searching toward the plume;
- predation and lysis therefore create observable ecological hotspots.

A true host/blood chemistry module is separately tracked in #52.

### Water/current

A first deterministic flow term advects organisms while preserving self-propulsion.

Future #48:
- vector flow field;
- field advection;
- vortices/wakes;
- EPS flow barriers;
- sedimentation.

### Light

A deterministic spatial light gradient currently drives producer activity and phototroph energy gain.

Current:
- deterministic 180 s day/night light cycle;
- producer activity and phototroph energy gain follow the cycle;
- dense producer biomass attenuates local effective light, creating self-shading;
- explicit microalgae visibly dim as local light falls.

The self-shading law is a qualitative ALife attenuation model, documented in `docs/MATH.md`; it is not presented as a calibrated optical model for a specific taxon or water column.

Future #56:
- oxygen/redox oscillation;
- diel migration/dormancy;
- richer depth/colony optics if later measurements justify them.

## Current bacterial ecotypes

The existing generic bacterial genotype now also carries a stable ecological guild.

### Heterotroph

General dissolved-resource competitor.

### Scavenger

Specialized for detrital niches.

- stronger access to detrital energy;
- chemotaxis includes detritus/damage cues;
- overlaps with the mobile scavenge plasmid but is not identical to it.

### Biofilm builder

Slower, more adhesive niche constructor.

- increased EPS secretion;
- reduced free-swimming speed;
- alters local movement conditions.

### Phototroph

Light-assisted producer ecotype.

- reduced motility;
- gains energy from light;
- releases oxygen;
- leaks a small amount of dissolved resource.

These are **ecotypes / functional guilds**, not claims that four real taxonomic species are being simulated.

## Explicit producer and decomposer organisms

### Microalgae-like producer

Individual producer cells now exist in addition to the producer-mat continuum.

Current behavior:
- evolve heritable light-use, growth, size, exudate and drift traits;
- gain energy from local light;
- take dissolved nutrient;
- release oxygen;
- leak a small organic-resource fraction;
- drift with water/current;
- divide through a staged visible reproduction state;
- lyse/recycle when energy collapses;
- can be grazed by ciliates and amoebae.

They are an ecological producer abstraction, not a claim to reproduce one particular algal taxon.

### Yeast-like decomposer

A distinct decomposer guild now consumes carrion/detritus.

Current behavior:
- evolves detritus uptake, mineralization, growth, size and metabolism;
- consumes the detritus field;
- returns part of detritus to dissolved nutrient;
- consumes oxygen and emits waste;
- biases drift weakly up local detritus gradients;
- reproduces by staged budding;
- lyses/recycles;
- can be grazed by ciliates and amoebae.

True hyphal branching and extracellular-enzyme chemistry remain future work in #54.

## Existing predator guilds

### Amoeboid predator

Slow deformable phagocytic grazer with staged engulfment.

### Ciliate-like grazer

Faster directional grazer.

Both:
- can reproduce from prey-derived energy;
- evolve heritable traits;
- can starve;
- visibly weaken and slow before terminal lysis;
- enter a visible death/lysis sequence;
- recycle into detritus;
- can orient toward damage plumes when no direct prey is detected.

Current trophic edges:
- ciliates graze bacteria, microalgae and yeast-like decomposers;
- amoebae graze bacteria, microalgae, decomposers and suitably small ciliates;
- prey remains visible during staged capture/engulfment;
- feeding leaks detritus and damage cues back into the biome.

## Death and recycling contract

Death must never be only `entity -> delete`.

Observable chain:

1. energetic stress / lethal event;
2. visible dying state;
3. membrane/body deformation or fragmentation;
4. dissolved damage cue;
5. detrital biomass;
6. scavenger/decomposer attraction;
7. resource re-entry into the food web.

Predation similarly has pursuit, contact, handling/engulfment, prey disappearance inside the predator and leakage/recycling.

## Research-backed expansion map

### Microbial loop

Aquatic food webs recycle dissolved organic matter through bacteria, protists and viruses. This motivates producer -> DOM -> bacteria -> grazers -> death/recycling loops.

Reference:
- https://www.nature.com/articles/nrmicro1180
- https://pmc.ncbi.nlm.nih.gov/articles/PMC4962909/

### Cross-feeding

Metabolites produced by one population can become resources for another, with optional or obligate dependencies.

Tracked by #42.

Reference:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC8721230/

### Phycosphere

Microscale bacterial interactions around individual phytoplankton cells can form distinct local niches.

Tracked by #53.

Reference:
- https://www.nature.com/articles/nmicrobiol201765
- https://www.nature.com/articles/s41564-026-02287-6

### Biofilm heterogeneity

Biofilms create nutrient, oxygen, waste and signaling gradients and can intensify local interaction/HGT.

Tracked by #34 and #43.

References:
- https://www.nature.com/articles/nrmicro2415
- https://www.nature.com/articles/s41579-022-00692-2

### Dormancy / microbial seed bank

Dormancy can preserve rare genotypes and stabilize communities through environmental fluctuations.

Tracked by #33 and #51.

Reference:
- https://www.nature.com/articles/nrmicro2504

### Predation / coevolution

Microbial predation can reshape morphology, behavior, genetics and community stability.

Tracked by #35, #45 and #49.

Reference:
- https://www.nature.com/articles/s41579-026-01299-7

### Viral control / viral shunt

Phage infection provides a top-down control while returning host material to dissolved resource pools.

Tracked by #30.

Reference:
- https://www.nature.com/articles/s41579-019-0270-x

### Chemotactic damage cues

Bacteria can respond to many chemoeffectors, including amino acids, organic acids, oxygen and other metabolically informative compounds.

This supports the generic lysis/damage plume mechanic.

Reference:
- https://journals.asm.org/doi/10.1128/jb.00300-24

### Microbial mats / diel gradients

Photosynthetic oxygen production and respiration can generate strong spatial and temporal chemical gradients.

Tracked by #40, #50 and #56.

Reference:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12168310/

### Larger microfauna

Aquatic micro-food webs can include bacteria, fungi, algae, protozoa and later larger microfauna such as rotifers/nematodes.

Tracked by #44, #54 and #55.

References:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC12372383/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC7120757/

## Issue map

- #38 biome epic
- #39 oxygen/light/detritus/EPS/damage fields
- #40 explicit phototroph/cyanobacterial producers
- #41 scavengers / carrion chemotaxis
- #42 metabolic cross-feeding
- #43 EPS/biofilm ecosystem engineering
- #44 expanded organism guilds/morphologies
- #45 visible feeding/death/recycling animation
- #48 water flow / hydrodynamics
- #49 multi-trophic predation
- #50 pH/temperature/redox/toxicity
- #51 succession/disturbance
- #52 optional host-tissue/blood chemistry
- #53 phycosphere symbiosis
- #54 fungi/yeast/hyphae decomposers
- #55 rotifer/nematode microfauna
- #56 day/night/diel cycle
- #57 fused GPU multi-field biome compute
- #61 generative pixel biome atlas / biological event FX

Evolution continues through #13, #30–#36.

## Performance architecture

The CPU implementation is the deterministic reference, not the final scaling path.

Current multi-rate mitigation:
- nutrient/waste/oxygen/damage chemistry: 30 Hz;
- detritus/EPS/producer growth: 10 Hz;
- organism biology/mechanics: 60 Hz.

Issue #57 owns the fused GPU biome path.

Biome fields are explicitly intended for GPU compute:
- one or more packed field textures/buffers;
- fused diffusion/decay/advection kernels;
- producer/source/sink passes;
- no full per-tick GPU readback;
- visualization should consume GPU-resident fields directly.

Agent populations should remain bounded until GPU-resident agent mechanics is validated.

## Visual contract

The biome is a slowly evolving ecological material layer, not a heatmap and not animated wallpaper.

Rendering layers:
1. dedicated low-contrast water shader;
2. dedicated biome shader driven by slow simulation masks;
3. organism sprites;
4. local biological-event FX.

All game art uses the same **0.25 world-unit source-pixel scale**.

Producer biomass reveals clustered chlorophyll/mat pixels; EPS reveals sparse teal matrix; detritus reveals particulate brown fragments; damage/lysis reveals short-lived warm residue. Oxygen/nutrient/waste remain subordinate micro-grains. Most water remains uncovered.

Shader coordinates are spatially stable. There is no global frame-swapping animation. Masks refresh slowly from real simulation fields, so patches change only as the simulation changes. Bacterial producer/EPS/scavenger activity, feeding and death modify the fields that drive these visuals.

Action/reaction FX use a compact shared 7x7 atlas at the same source-pixel scale: division, adhesion, reproduction, pursuit, feeding, digestion, stress and lysis.

Issue #61 owns this game-art presentation layer. Issue #57 owns migration to a GPU-resident path.


## 2026-10-03 renderer/simulation audit

Two concrete faults were found after the black/no-biome recordings:

- Godot `Polygon2D` only builds its UV vertex data when a valid texture is assigned. The shader quads had custom UV arrays but no texture, so their shaders effectively sampled the same mask corner across the whole polygon. The renderer now assigns a 1x1 opaque UV-driver texture solely to make the intended 0..1 UVs reach the shaders.
- producer-mat growth previously omitted the biomass term in its logistic growth law, allowing zero-biomass cells to create producers spontaneously. Growth now requires an existing seed, while a very small diffusion term provides slow spatial spread. Seed sources, explicit microalgae and phototrophic bacteria can establish/strengthen producer material.

The visual consequence should be stable water plus slowly changing, spatially attributable ecological patches rather than either a black dish or full-screen animated wallpaper.


## Cross-feeding / quorum / dormancy slice (#62)

The active ecosystem now includes two additional bounded scalar fields:
- **labile exudate** — local soluble metabolites released by microalgae, phototrophic bacteria and decomposers;
- **quorum signal** — a short-lived density signal released by active bacteria.

Interactions:
- bacteria chemotax partly toward exudate and can use it as a second dissolved energy/resource channel;
- EPS-rich patches increase effective exudate capture, creating a retention advantage for attached communities;
- biofilm builders emit more signal, and high local signal increases EPS investment while reducing free-swimming speed;
- EPS slows protist handling/engulfment, making dense matrix a real grazing refuge with an energetic production cost;
- low-resource bacteria can enter a reversible low-metabolism dormant state and wake when dissolved resource/exudate returns;
- microalgae create local phycosphere-like exudate niches; decomposers create cross-feeding products while mineralizing detritus.

These are qualitative ecosystem mechanisms, not calibrated metabolite chemistry or a claim that one universal quorum molecule exists across all bacteria. The fields remain GPU-friendly and run on the slow biome cadence in the CPU reference.


## Flagellate bacterivore tier (#63)

A new small flagellate-like protist now occupies the intermediate grazer niche:
- primarily hunts bacteria;
- uses a distinct 14x9 cached pixel silhouette with a frame-authored flagellum;
- staged feeding keeps bacterial prey visible during capture;
- reproduces from prey-derived energy and lyses/recycles under starvation;
- follows exudate gradients when direct prey is absent, indirectly coupling it to producer phycospheres;
- can itself be captured by larger ciliates and amoebae.

This creates a bounded tri-trophic chain: **bacteria -> flagellates -> ciliates/amoebae**, while flagellates and ciliates compete for bacterial prey. The first slice is deliberately capped at 28 agents and does not add another unbounded search structure.


## Succession / disturbance cycle (#51)

The CPU-reference ecosystem now has a deterministic slow disturbance cycle, starting after the initial establishment window and then repeating at long intervals. It deliberately changes **fields**, not arbitrary organism state:

- **resource pulse**: local dissolved nutrient/oxygen enrichment creates a bloom opportunity;
- **washout**: locally strips producer mat, EPS/quorum and some exudate, while detached material becomes detritus and fresh water raises oxygen;
- **organic fall**: a particulate detritus pulse favors decomposers/scavengers, then cross-feeders through mineralization/exudation.

Event positions are derived from seed + event index without consuming the main simulation RNG, preserving deterministic mutation/predation streams. This creates colonization fronts, dormancy/wake cycles, producer recovery and changing trophic hotspots using the existing ecological mechanisms instead of scripted species replacement.


## Natural transformation / extracellular DNA (#32)

Bacterial lysis now releases a **bounded pool of extracellular DNA fragments** (hard ceiling 64). Each fragment carries one chromosomal trait sample plus donor-lineage similarity metadata.

- competence is a heritable bacterial trait with a metabolic cost;
- competence is induced by moderate starvation/damage stress, and is distinct from dormancy;
- competent nearby cells can take up fragments;
- lineage/color similarity modulates homologous recombination likelihood;
- successful recombination partially pulls one recipient trait toward the donor value;
- incompatible uptake is still worth a small nutrient return;
- fragments drift slowly with water flow and decay after a bounded lifetime;
- no plasmid module is transferred by this path, keeping natural transformation distinct from #31 conjugation;
- extracellular DNA has a tiny cached pixel-art fragment asset visible only at close microscope zoom.

The fragment pool is deliberately bounded and updated on the slow biome cadence so the feature does not become an unbounded particle system.


## Predator-prey coevolution slice (#35)

Predation now acts on existing visible/costly bacterial phenotypes rather than an invisible resistance stat.

- higher adhesion and local EPS increase handling difficulty;
- larger bacterial morphology increases handling difficulty;
- dormancy gives a small handling advantage;
- local EPS extends handling time for any prey occupying the matrix;
- sufficiently defended bacteria can escape an active handling event;
- amoeba engulfment, ciliate capture and flagellate capture traits counter these defences.

The trade-offs already exist in the same phenotypes: matrix secretion costs energy and reduces mobility, larger cells pay drag/maintenance costs, and dormancy sacrifices growth. Predator capture/engulfment genes already mutate, creating a first explicit eco-evolutionary arms race.


## Filamentous hyphal decomposer slice (#54)

The decomposer guild now includes true bounded branching hyphal colonies in addition to budding yeast-like cells.

- each colony is a resource-driven node graph, capped at 24 nodes;
- tips sample/consume local detritus and bias growth toward detrital gradients;
- branching only occurs when substrate/energy support it;
- tips secrete an extracellular fungal-enzyme field;
- enzyme converts part of particulate detritus into dissolved nutrient and labile exudate, feeding bacteria and producers;
- colony maintenance scales with network size;
- starved colonies decay and recycle their network back into detritus/damage;
- mature energetic colonies can sporulate into a new bounded colony;
- yeast and hyphae therefore compete for detritus while creating different cross-feeding structures.

Rendering uses cached segment/tip/junction pixel assets at the same 0.25-world-unit source-pixel scale; the visible branching pattern comes from the real growth graph, not decorative procedural lines.
