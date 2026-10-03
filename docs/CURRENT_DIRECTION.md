# CURRENT DIRECTION — read before changing MicroC0re

**Status:** visual/performance reset decided 2026-10-02.

This file is the highest-priority product direction for coding/design agents. If another document conflicts with it, follow this file first, then update the conflicting document.

## Why the reset exists

The first visible prototype proved that the simulation can run and be inspected, but it is **not an acceptable visual or performance baseline**.

Observed problems:
- the world reveals Godot's grey/default clear area when zooming out;
- close zoom with roughly 130 organisms was observed around 5–8 FPS;
- organism rendering reads as smooth procedural/vector capsules and lines, not deliberate pixel art;
- flagella/pili are thin procedural strokes rather than designed pixel animation;
- the chemical field looks like a coarse debug grid rather than a coherent microscopic environment;
- there is no real LOD strategy;
- growth/division/contact are not visually staged strongly enough;
- fusion/engulfment/predation/adhesion are not yet readable as persistent interactions;
- zoom currently makes expensive detail rendering scale badly.

Do not "polish" this exact renderer. Rebuild the visual pipeline around the rules below.

## Product north star

MicroC0re should look like an **interactive generative pixel-art microscope** showing a living, evolving microscopic ecosystem.

The viewer should be able to:
- zoom from a large ecosystem overview to a close organism inspection;
- pan freely without ever seeing accidental grey/undefined background;
- immediately read different organisms/lineages at normal zoom;
- see deliberate pixel-level structure at close zoom;
- observe interactions that persist long enough to understand: growth, fission, adhesion, feeding, lysis, later predation/engulfment;
- watch the system evolve without needing a debug explanation;
- inspect an individual organism and understand how its lineage/traits differ;
- witness both vertical mutation and horizontal acquisition of mobile traits.

The simulation remains continuous and deterministic where intended. The **presentation** is pixel art.

## Current priority order

Until Epic #14 is complete, work in this order:

1. **#17 Performance / profiling / overload behavior**
2. **#59 Smooth LOD transitions / readable overview silhouettes**
3. **#18 + #45 Readable organic animation / feeding / death / recycling**
4. **#57 GPU-resident biome fields**, after the visible baseline is readable and benchmarked
5. Small ecology slices may proceed only when they materially improve visible interactions and stay inside the measured performance budget.

The 2026-10-03 live RTX review explicitly rejected the current interaction readability and hard LOD transitions. Do not treat technically present feeding/death states as finished merely because smoke tests pass.

This priority order is intentional: do not add expensive visual detail or unbounded species systems before we know the render budget.

## GPU-first desktop rule

The desktop performance target is now **GPU-first where the work is massively parallel**.

- Forward+ / RenderingDevice is the primary desktop renderer.
- Use GPU instancing for large visible populations.
- Move continuum chemistry and later agent hot loops to compute shaders when the state can remain GPU-resident.
- Keep CPU reference/headless modes for correctness and CI.
- Do not force CPU use merely for architectural simplicity.
- Equally, do not introduce a per-tick full GPU readback: synchronization can erase the GPU advantage.
- Issue #27 owns the GPU migration.

## Non-negotiable performance contract

For the agreed baseline scene on the maintainer workstation:
- target: sustained **120 FPS** during normal microscope inspection;
- development floor: **60 FPS**;
- no feature is considered "done" based on appearance alone;
- profile simulation, chemistry, texture upload, organism rendering, appendages and HUD separately;
- off-screen organisms must be culled;
- far/mid/near/macro zoom levels must use explicit LOD;
- distant organisms must not pay the cost of close-up appendage/detail rendering;
- large populations should use GPU instancing/bulk buffers where appropriate;
- do not claim an optimization worked without measured before/after numbers.

Simulation tick rate and render FPS are separate concerns. Current contract: biology at deterministic 60 Hz, chemistry at 30 Hz, presentation targeting 120+ FPS. A high simulation tick rate is not evidence of fluid rendering.

## Pixel-art contract

Nearest-neighbor filtering is **not sufficient** to call the result pixel art.

The final organism presentation must use deliberate low-resolution sprite/sprite-part design with:
- controlled pixel clusters;
- limited palettes and coherent color ramps;
- intentional outlines / selective outlines;
- no accidental smoothing;
- no arbitrary subpixel vector detail;
- animation designed as key poses / frames;
- silhouette readability before internal detail;
- integer-friendly presentation at normal zoom.

Reference reading:
- Lospec: https://lospec.com/articles/pixel-art-where-to-start/
- PixelJoint / Cure tutorial: https://pixeljoint.com/forum/forum_posts.asp?TID=11299

The exact internal resolution, sprite sizes, palette and animation budgets belong in `docs/ART_DIRECTION.md` and Issue #15.

## Camera / world contract

The microscope must feel continuous even when the finite simulation domain is visible.

Required:
- no Godot default grey/clear pixels at any supported zoom;
- screen-space background always covers the viewport;
- optional repeated/procedural microscope microtexture outside the active Petri region;
- zoom toward cursor;
- stable pan at every zoom;
- **overview-or-zoom-in only**: the minimum zoom must cover the viewport with simulated world;
- camera position must be clamped so panning never exposes outside-world space;
- F returns to the overview;
- close zoom for pixel/sprite inspection.

"World is finite" is acceptable. "Outside world is accidental grey" is not.

## UI / inspection contract

The simulation view should read as artwork first, not as a developer dashboard.

A click is also a microscope focus action: the selected organism should be centered and followed while it moves. Manual pan or Fit exits follow mode. The compact inspector must remain a small annotation card rather than occupying a major fraction of the scene.

Required:
- no permanent FPS/debug/status block in the microscope view;
- no F1 debug overlay as the primary interface;
- Escape opens a real pause menu;
- clicking an organism opens a left-side detail inspector;
- the inspector shows identity, lineage, generation, energy/state and heritable traits;
- bacterial mobile DNA / HGT state should be visible in the inspector;
- clicking empty world or pressing Escape closes the inspector;
- diagnostic profiling remains available through development tools/benchmarks, not permanent screen clutter.

## Organism design contract

The current procedural capsule is a temporary debug shape.

Initial sprite/morphology families should include:
- rod / bacillus;
- coccus / clustered coccus;
- curved / vibrio-like;
- amoeboid/protist predator for true engulfment/deformation;
- ciliate-like grazer for fast top-down control.

At close zoom, morphology may expose:
- wall/membrane;
- cytoplasm;
- nucleoid-like regions;
- flagella;
- pili/fimbriae;
- granules / vacuole-like structures where biologically appropriate;
- lineage-specific body proportions.

Do not invent eukaryotic "organelles" inside bacteria merely for decoration.

## Animation / interaction contract

Movement alone is not enough to communicate life.

First readable sequences:
- propulsion cycle;
- tumble/reorientation cue;
- growth;
- binary fission with visible constriction and daughter separation;
- collision/contact response;
- temporary adhesion / chaining;
- starvation;
- staged death / lysis.

Later:
- conjugation bridges;
- biofilm matrix/adhesion;
- predatory bacterial attacks;
- amoeboid/protist engulfment;
- ciliate grazing;
- bacteriophage infection/lysis later;
- artificial-life fusion only when clearly documented as fictional rather than ordinary bacterial biology.

Important interactions should persist long enough to observe. Avoid `collision -> delete`.

## Living biome direction

Epic #38 is now an active product direction alongside the visual rebuild.

The simulated world should evolve into an aquatic micro-ecosystem with:
- oxygen, light, detritus, EPS, damage cues and water flow;
- producer, heterotroph, scavenger and biofilm niches;
- protist grazing and later multi-trophic predation;
- visible death/recycling;
- cross-feeding and niche construction;
- succession/dormancy;
- later phages, fungi and larger microfauna.

Read `docs/BIOME.md` before ecology/environment changes.

## What agents should NOT do right now

While Epic #14 remains open, do not:
- add cosmetic species just to make the screen busier; new guilds are allowed when they occupy a real niche defined in `docs/BIOME.md`;
- add expensive shaders/effects before profiling;
- keep extending procedural line/circle organism art as the final style;
- add complex predation that has no visual state machine;
- optimize blindly;
- equate a low-resolution chemical texture with a finished pixel-art direction;
- hide grey world edges by merely clamping the camera without designing the background;
- merge visual changes that look better but make the baseline fall below 60 FPS.

## Gate to resume ecology

Epic #14 is ready to unblock deeper ecology when:
- no grey/undefined background is visible at supported zoom;
- baseline scene sustains the agreed performance target or has a quantified, accepted remaining bottleneck;
- organisms use the new pixel-art pipeline;
- LOD is working;
- fission is visually readable;
- at least one persistent contact/adhesion interaction is visually readable;
- the art bible defines resolution, palette, sprite families and animation budgets.

## Source of truth

- Epic: #14
- Pixel art: #15
- Camera/background: #16
- Performance/LOD: #17
- Animation/interactions: #18
- Renderer umbrella: #7
- Simulation performance: #9
- Ecology research: #10
- Evolution: #13
