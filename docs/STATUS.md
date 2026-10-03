# Project status

This file is the human/agent-readable mirror of the MicroC0re workflow.

**Canonical state lives in the GitHub Project `MicroC0re`, in its `Status` field / board columns.**

Issue titles must not contain workflow prefixes such as `[TODO]`, `[IN PROGRESS]`, `[REVIEW]` or `[BACKLOG]`. Bracketed title tags are reserved for technical/domain categories.

When an agent cannot mutate Project V2 directly, use the connector-writable `status:*` label protocol from `docs/HANDOFF.md`; the default-branch workflow synchronizes the real Project card.

## IN PROGRESS

- #1 Petri Kernel v0.1 epic
- #3 rod/spherocylinder mechanics
- #7 pixel microscope renderer
- #8 validation / invariants
- #9 spatial indexing / profiling
- #10 predation / engulfment / microbial interactions
- #13 evolution / heritable genotype
- #14 Visual Rebuild v0.2
- #15 true pixel-art pipeline / art bible
- #17 performance / profiling / LOD
- #18 readable life animation and interactions
- #45 visible killing / feeding / lysis / recycling
- #23 GPU MultiMesh rendering
- #26 GPU compute path research
- #27 GPU-first desktop pipeline
- #28 amoeboid deformation / staged engulfment
- #29 trophic balance / evolving predators / population guard
- #38 living aquatic biome epic
- #40 explicit phototroph / microalgal producers
- #44 expanded organism guilds / morphologies
- #48 water flow / hydrodynamics
- #49 multi-trophic predation
- #54 yeast / fungal decomposer guild
- #56 day/night / diel oxygen cycle
- #57 fused GPU multi-field biome compute
- #60 living microscope watchability / cinematic observation
- #61 generative pixel biome atlas / biological event FX

## REVIEW

- #2 nutrient/waste scalar fields
- #4 temporal run-and-tumble chemotaxis
- #5 uptake / metabolism / growth / death / binary fission
- #16 camera / microscope framing / zoom / pan
  - overview-or-zoom-in only;
  - minimum zoom is cover-fit;
  - pan is clamped to the simulated world.
- #31 plasmid conjugation / horizontal gene transfer
- #39 oxygen/light/detritus/EPS/damage biome fields
- #41 scavengers / carrion / damage-cue chemotaxis
- #46 compact organism inspector
- #47 overview LOD consistency fix
- #59 smooth LOD transitions / readable overview silhouettes — first cross-fade pass awaiting live review

These Review items have passed GitHub Actions parse/smoke validation where applicable but still need maintainer live visual/behavior review.

## TODO

- #6 Turing / Gray-Scott laboratory
- #20 packed SoA organism storage
- #21 Verlet half-neighbor lists + skin / stencil
- #22 counter-based deterministic RNG
- #24 parallel CPU pipeline
- #30 bacteriophage kill-the-winner / viral recycling
- #32 natural transformation / extracellular DNA / competence
- #33 phenotypic switching / dormancy / division of labor
- #34 quorum sensing / EPS biofilm / cooperative-cheater evolution
- #35 predator-prey coevolution / bacterial defence traits
- #36 lineage tree / ancestry history / emergent phenotype clusters
- #42 metabolic cross-feeding
- #43 mature biofilm/EPS ecosystem engineering
- #50 pH / temperature / redox / toxicity
- #51 succession / disturbance / recolonization
- #52 optional host-tissue / heme / blood chemistry
- #53 phycosphere symbiosis
- #55 rotifer / nematode microfauna

## DONE

- #11 GitHub Actions Godot 4.7.1 smoke CI
  - GitHub Actions import + deterministic smoke test passing.
- #37 public repository readiness security audit
  - post-public full-history Gitleaks scan and sensitive-filename guard passing.

## BACKLOG / GATED

- #25 native C++ GDExtension kernel
  - only start if algorithmic/GPU/data-layout work still needs a native CPU kernel.

## Latest maintainer feedback — 2026-10-03

Local Windows / RTX 5080 validation at `58e8b0f`:
- smoke PASS with the hardened fail-closed runner;
- CPU benchmark: 100 = 9.886 ms/tick, 500 = 30.806 ms/tick, 1000 = 75.222 ms/tick;
- 1000-agent breakdown: chemistry 6.207 ms, agents 21.831 ms, mechanics 44.952 ms;
- GPU 96x64 diffusion benchmark: 1182.5 M cell-updates/s;
- visible app still develops severe long-run stutter under load;
- overview reads as isolated pixels;
- zoom transitions feel staged;
- biome/resource state is too subtle to understand visually;
- feeding, killing, death and recycling are technically present but not yet visually convincing.

Immediate active correction:
- selection now enters a centered camera-follow state, with manual pan/Fit as explicit escape;
- inspector is being reduced from the rejected ~218x374 internal panel to a ~144x108 compact watch card;
- selected organisms use a pixel microscope bracket reticle + motion wake rather than a raw rectangle;
- biome compositing is being rebalanced away from the flat green sqrt-amplified wash toward localized niches;
- division, adhesion, reproduction and feeding receive additional presentation-only event cues;
- bound visible-app catch-up work so slow ticks cannot trigger a multi-step freeze spiral;
- cross-fade overview markers into sprites rather than hard-swapping LOD;
- use small far silhouettes instead of one-square-pixel bacteria;
- strengthen field contrast for producer/detritus/damage/EPS/oxygen;
- add persistent pixel feeding links / vacuole cues and stronger lysis blooms.

Previous 2026-10-02 observations:
- the ecosystem still needs substantially more life, niches and interaction density;
- the overview showed one accidentally huge organism while other organisms were tiny;
- the left inspector was far too large;
- the world should become a real biome with water, producer/vegetation-like life, many ecological guilds, death, feeding and environmental modification;
- some organisms should seek damage/carrion-like chemical signals;
- interactions such as killing, feeding and death must be visibly animated;
- desktop remains GPU-first and population growth must never recreate the 1000-agent slowdown.

## Implemented in the current biome pass

### Rendering / UI
- fixed the stale absolute ciliate LOD threshold that caused a giant full sprite at overview;
- all three current organism classes now use overview-relative LOD logic;
- organism inspector reduced to a compact ~218 x 374 px panel with smaller typography;
- inspector remains scrollable and now exposes local biome values.

### Living biome
- dynamic oxygen field;
- detritus/carrion field;
- EPS/biofilm matrix field;
- transient damage/lysis cue field;
- producer-biomass / microbial-mat field;
- deterministic spatial light model;
- deterministic water-current advection;
- producer mats grow under light and oxygenate/leak resource into the system;
- aerobic energy yield responds to local oxygen;
- death and active feeding return material to detritus and emit damage cues;
- scavenger ecotypes/plasmid carriers chemotax toward detritus/damage plumes;
- water-current advection affects all current mobile organism classes;
- a deterministic 180 s diel light cycle drives producer activity and oxygenation;
- producer mats now self-shade, reducing effective light for dense producer patches; explicit microalgae visibly respond to local light;
- renderer converts nutrient, waste, oxygen, producers, EPS, detritus and damage into deterministic 4x4 pixel-art biome motifs instead of exposing them as a flat heatmap.

### Functional diversity
Bacteria now include four heritable functional ecotypes:
- heterotroph;
- scavenger;
- biofilm builder;
- phototroph.

Current niche effects:
- scavengers consume detritus and chemotax toward carrion/damage signals;
- biofilm builders secrete more EPS and swim more slowly;
- phototrophs gain light-assisted energy and release oxygen;
- heterotrophs remain general dissolved-resource competitors;
- bacterial ecotypes now use distinct cached pixel silhouettes instead of color-only reskins.

Explicit non-bacterial guilds now also exist:
- evolving microalgae-like producers with light-driven oxygenation, exudates, division and lysis;
- evolving yeast-like decomposers with detritus consumption, mineralization, budding and lysis.

### Predation / death
- amoebae and ciliates can bias search toward damage plumes when direct prey is absent;
- ciliates graze bacteria, microalgae and yeast-like decomposers;
- amoebae graze bacteria, microalgae, decomposers and suitably small ciliates;
- active predation leaks detritus/damage cues into the local biome;
- low-energy amoebae/ciliates visibly weaken and slow before terminal lysis;
- starved amoebae/ciliates enter a staged lysis/death state instead of disappearing instantly;
- predator death renders fragments/fade and recycles biomass;
- a regression test now verifies ciliate feeding remains attached to non-bacterial prey across frames.

### Generative biome / event asset pass
- new cached `pixel_biome_atlas.gd` generates deterministic 4x4 water, producer, detritus, EPS, damage, oxygen and nutrient motifs;
- simulation fields select motif family + density; a secondary field contributes a small accent for mixed niches;
- the composed biome texture is now 384x256 for the current 96x64 field, retaining crisp world-scale pixel clusters;
- new cached `pixel_effect_atlas.gd` defines division, adhesion, reproduction, feeding, lysis and stress FX;
- field-art refresh is limited to 10 Hz to control CPU-reference presentation cost; #57 remains the GPU path.

### Interaction / microscope readability pass
- visible app now limits wall-clock catch-up work; stale backlog is dropped instead of running many expensive ticks in one frame;
- overview bacteria use GPU-instanced rod-like silhouettes instead of isolated square pixels;
- overview markers cross-fade into full sprites over a relative zoom band;
- mouse-wheel zoom increments are smaller;
- bacteria/microalgae/decomposers expose low-energy visual stress cues;
- active protist feeding draws persistent pixel transfer/handling cues;
- lysis now emits a stronger warm pixel bloom that hands off visually into damage/detritus fields;
- biome field contrast is stronger for detritus, damage cue, EPS, oxygen and producers;
- amoeba/ciliate ingestion timings are longer so events remain observable.

### Validation
- deterministic smoke signature includes new biome totals, bacterial guild and predator death state;
- smoke tests validate non-negative biome fields and guild/lysis invariants;
- latest Godot Actions smoke passed after the producer/decomposer, multi-trophic and starvation passes;
- slow biome fields run at 10 Hz while fast chemistry remains 30 Hz to control CPU-reference cost;
- #57 owns migration of the expanded biome fields into fused GPU compute.

## Research / roadmap

See `docs/BIOME.md`.

Key researched future layers:
- microbial loop / dissolved-organic recycling;
- phytoplankton/cyanobacteria and phycosphere symbiosis;
- metabolic cross-feeding;
- mature EPS/biofilm niche construction;
- dormancy / seed-bank dynamics;
- phage viral shunt / kill-the-winner;
- fungi/yeast decomposition;
- multi-trophic predation;
- diel light/oxygen cycles;
- larger microfauna such as rotifer/nematode-like consumers;
- optional host-tissue chemistry.

## Rule for agents

Before starting work:
1. read `docs/HANDOFF.md`;
2. read `docs/CURRENT_DIRECTION.md`;
3. read this file;
4. read the issue being worked on;
5. for biome/ecology work, read `docs/BIOME.md`;
6. for evolution work, read `docs/EVOLUTION.md`;
7. for performance/GPU work, read `docs/OPTIMIZATION_STRATEGY.md`;
8. finish blocking In Progress / Review work before starting unrelated Todo work.

When status changes:
1. update the GitHub Project Status directly when possible;
2. otherwise use the matching `status:*` connector label;
3. update this file when the summarized workflow materially changes.

Do not put workflow state back into issue titles.
