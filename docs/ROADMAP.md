# Roadmap

GitHub Issues are the source of truth for active work. This file describes sequencing and gates.

## Phase 0 — repository bootstrap

- [x] Define scientific/art direction.
- [x] Define hybrid agent/continuum architecture.
- [x] Add primary research references.
- [x] Define validation levels.
- [x] Create Petri Kernel v0.1 epic and child issues.
- [ ] Merge the bootstrap PR.
- [ ] Run the first headless smoke test on Godot 4.7.1.
- [ ] Issue #11 — enable the same smoke test in GitHub Actions.

## Phase 1 — Petri Kernel v0.1

Tracked by Issue #1.

Core:
- Issue #2 — continuous fields and diffusion.
- Issue #3 — rod mechanics.
- Issue #4 — run-and-tumble chemotaxis.
- Issue #5 — uptake, metabolism, growth, death, fission.
- Issue #8 — validation and determinism.

Presentation:
- Issue #7 — living pixel microscope renderer, camera, HUD, appendages.
- Issue #13 — heritable genotype, visible phenotype, mutations and lineages.

Research lane:
- Issue #6 — Turing / Gray-Scott laboratory.

Performance:
- Issue #9 — profiling and deterministic spatial indexing.

## Gate for v0.1

Do not expand ecology until:
- headless tests pass;
- same seed is reproducible;
- starved/fed behavior is sensible;
- chemotaxis A/B test exists;
- mechanics does not explode numerically;
- rendering remains independent.

## Phase 1.5 — Visual Rebuild v0.2 (CURRENT GATE)

Tracked by Epic #14.

Priority order:
1. #17 — performance profiling / 120 FPS target / LOD;
2. #16 — infinite-feel background and robust zoom/pan;
3. #15 — true pixel-art pipeline and art bible;
4. #18 — readable organic animation and interactions.

The current visible renderer is not a final art baseline. Do not add deep ecology until this gate is sufficiently complete.

Gate conditions:
- no grey/undefined area at supported zoom;
- baseline scene meets the agreed FPS target or has quantified remaining bottlenecks;
- organisms use the new pixel-art pipeline;
- far/mid/near/macro LOD exists;
- fission is visually readable;
- at least one persistent adhesion/contact interaction is visually readable;
- art bible defines resolution, palette, sprite families and frame budgets.

## Phase 2 — ecology

Issue #10 starts this research.

Candidate systems:
- lysis and recycling;
- predatory bacteria;
- amoeboid/protist predator;
- engulfment;
- adhesion;
- quorum-like signaling;
- early biofilm matrix;
- conjugation/genetics.

Each should arrive as a model + reference + validation plan, not as a visual shortcut.

## Phase 3 — open-ended evolution / advanced art direction

The first heritable trait layer is already part of Phase 1. Later work can add:
- neural / regulatory controllers;
- explicit speciation and lineage trees;
- horizontal gene transfer;
- richer selection pressures;
- ecosystem presets;
- long-running deterministic seeds;
- curated pixel palettes;
- shader/CRT/microscope treatments;
- capture/export modes.
