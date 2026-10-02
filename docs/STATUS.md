# Project status

This file is the human/agent-readable mirror of the MicroC0re workflow.

**Canonical state lives in the GitHub Project `MicroC0re`, in its `Status` field / board columns.**

Issue titles must not contain workflow prefixes such as `[TODO]`, `[IN PROGRESS]`, `[REVIEW]` or `[BACKLOG]`. Bracketed title tags are reserved for technical/domain categories.

When an agent cannot mutate Project V2 directly, `scripts/sync_project_board.ps1` synchronizes the real board through authenticated GitHub CLI / GraphQL.

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
- #31 plasmid conjugation / horizontal gene transfer

## REVIEW

- #2 nutrient/waste scalar fields
- #4 temporal run-and-tumble chemotaxis
- #5 uptake / metabolism / growth / death / binary fission
- #16 camera / microscope framing / zoom / pan
  - latest implementation is **overview-or-zoom-in only**;
  - minimum zoom is cover-fit;
  - pan is clamped so the viewport cannot leave the simulated world;
  - awaiting maintainer visual validation.

## TODO

- #6 Turing / Gray-Scott laboratory
- #11 GitHub Actions headless CI
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

## BACKLOG / GATED

- #25 native C++ GDExtension kernel
  - only start if algorithmic/GPU/data-layout work still needs a native CPU kernel.

## Latest maintainer feedback — 2026-10-02

Observed:
- pixel-art organisms are improving but the ecosystem still needs stronger visible evolution;
- predator populations previously overshot prey;
- zoom-out to a tiny world is rejected;
- all permanent top-left debug/F1 UI is rejected;
- clicking an organism should open a real detail panel;
- Escape should open a clean menu;
- evolution should include mutation, visible transformation, trait exchange and later richer ecological mechanisms;
- desktop remains GPU-first.

Implemented on the current branch:
- no permanent HUD / no F1 debug overlay;
- Escape pause menu with Resume / Fit / Reset / New Seed / Quit;
- click bacteria, amoebae or ciliates to open a left-side live inspector;
- click empty world or Escape to close the inspector;
- overview zoom fills the viewport and cannot zoom farther out;
- camera pan is clamped to the simulated world;
- LOD thresholds now scale from the overview zoom;
- amoeboid and ciliate predators evolve, reproduce and starve;
- initial predators reduced and predator reproduction/energy gain retuned after observed prey collapse;
- CPU-reference safety ceilings remain 420 bacteria / 18 amoebae / 16 ciliates;
- bacteria can now exchange mobile plasmid traits by staged direct-contact conjugation;
- plasmid transfer has a visible pixel bridge and appears in the organism inspector;
- researched next evolution layers are #32 natural transformation, #33 phenotype switching/division of labor, #34 quorum/EPS, and #30 phage-mediated kill-the-winner dynamics;
- GPU compute benchmark is confirmed on the RTX 5080 at ~1455.3 M 96x64 field-cell updates/s in the dedicated benchmark.

## Rule for agents

Before starting work:
1. read `docs/CURRENT_DIRECTION.md`;
2. read this file;
3. read the issue being worked on;
4. for evolution work, read `docs/EVOLUTION.md`;
5. for performance/GPU work, read `docs/OPTIMIZATION_STRATEGY.md`;
6. do not start a TODO/BACKLOG item merely because it is interesting while an IN PROGRESS gate is blocking the visible product.

When status changes:
1. update the GitHub Project `Status` field;
2. update this file if the summarized workflow changed.

Do not put workflow state back into issue titles.
