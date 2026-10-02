# Project status

This file is the human/agent-readable status board for MicroC0re.

GitHub issue titles carry the same status prefix so the state is visible even when GitHub Project fields are not available to an automation agent.

## IN PROGRESS

- #14 Visual Rebuild v0.2
- #15 true pixel-art pipeline / art bible
- #17 performance / profiling / LOD
- #18 readable life animation and interactions
- #10 predation / engulfment / lysis / microbial interactions
- #23 GPU MultiMesh rendering
- #26 GPU compute research
- #27 GPU-first desktop pipeline
- #28 amoeboid deformation / hunting / staged engulfment
- #29 trophic balance / evolving predators / population guard

## REVIEW

- #16 infinite-feel background / zoom / pan
  - grey outside-world leak appears fixed in the latest maintainer screenshot;
  - needs extreme zoom/pan regression testing before closure.

## TODO

- #20 packed SoA organism storage
- #21 Verlet half-neighbor lists + skin / stencil
- #22 counter-based deterministic RNG
- #24 parallel CPU pipeline

## BACKLOG / GATED

- #25 native C++ GDExtension kernel
  - only start if algorithmic/GPU/data-layout work still needs a native CPU kernel.

## Latest maintainer feedback

2026-10-02:
- pixel-art organism direction is improving;
- the debug HUD obscured too much of the scene;
- ecosystem was still visually boring / hard to understand;
- user specifically wants more deformation, engulfment/mixing-like interactions and visible life processes;
- performance must remain aggressive and GPU-first on desktop.

Response implemented on current branch:
- compact one-line HUD by default; F1 toggles diagnostics;
- distinct amoeboid/protist class instead of biologically implausible bacterial fusion;
- amoeboid predators now reproduce, starve and evolve heritable speed/perception/engulfment/size/metabolism traits;
- second ciliate-like predator guild with animated cilia, fast grazing, reproduction and heritable mutation;
- CPU-reference live ecology is capped at 420 bacteria + bounded predator populations so runaway growth cannot recreate the 1000-agent slowdown;
- 6-frame deforming pixel-art protozoan atlas;
- staged hunting/engulfment where prey remains visible and is pulled inside over time;
- engulfment counter in diagnostics;
- denser 72-bacterium visible demo;
- clustered founder seeding around resource patches so contact/competition happens sooner;
- protozoa seed near active resource patches to make predation observable sooner.

## Rule for agents

Before starting work:
1. read `docs/CURRENT_DIRECTION.md`;
2. read this file;
3. read the issue being worked on;
4. do not start a TODO/BACKLOG item merely because it is interesting while an IN PROGRESS gate is blocking the visible product.

When status changes, update both:
- the GitHub issue title prefix;
- this file.
