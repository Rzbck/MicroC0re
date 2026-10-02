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
- #23 GPU MultiMesh rendering
- #26 GPU compute path research
- #27 GPU-first desktop pipeline
- #28 amoeboid deformation / staged engulfment
- #29 trophic balance / evolving predators / population guard
- #38 living aquatic biome epic
- #44 expanded organism guilds / morphologies
- #45 visible killing / feeding / lysis / recycling

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
- #40 explicit phototroph/cyanobacterial producer organisms
- #42 metabolic cross-feeding
- #43 mature biofilm/EPS ecosystem engineering
- #48 water flow / hydrodynamics
- #49 multi-trophic predation
- #50 pH / temperature / redox / toxicity
- #51 succession / disturbance / recolonization
- #52 optional host-tissue / heme / blood chemistry
- #53 phycosphere symbiosis
- #54 fungi / yeast / hyphal decomposers
- #55 rotifer / nematode microfauna
- #56 day/night / diel oxygen cycle

## DONE

- #11 GitHub Actions Godot 4.7.1 smoke CI
  - GitHub Actions import + deterministic smoke test passing.
- #37 public repository readiness security audit
  - post-public full-history Gitleaks scan and sensitive-filename guard passing.

## BACKLOG / GATED

- #25 native C++ GDExtension kernel
  - only start if algorithmic/GPU/data-layout work still needs a native CPU kernel.

## Latest maintainer feedback — 2026-10-02

Observed:
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
- renderer composites nutrient, waste, oxygen, producers, EPS, detritus and damage plumes.

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
- heterotrophs remain general dissolved-resource competitors.

### Predation / death
- amoebae and ciliates can bias search toward damage plumes when direct prey is absent;
- active predation leaks detritus/damage cues into the local biome;
- starved amoebae/ciliates now enter a staged lysis/death state instead of disappearing instantly;
- predator death renders fragments/fade and recycles biomass.

### Validation
- deterministic smoke signature includes new biome totals, bacterial guild and predator death state;
- smoke tests validate non-negative biome fields and guild/lysis invariants;
- latest Godot Actions smoke passed after the biome implementation.

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
