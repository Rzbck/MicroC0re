# Art direction — Living Microscope

## Reset decision — 2026-10-02

The first visible renderer is **rejected as the final visual direction**. It is useful only as a debug/prototyping layer.

Specific failures observed:
- vector-like capsules and procedural lines instead of deliberate pixel sprites;
- grey/undefined area visible when zooming out;
- severe close-zoom performance collapse (roughly 5–8 FPS observed around 130 organisms);
- insufficient LOD;
- animations too procedural/basic;
- fission, adhesion, predation/engulfment and other interactions are not readable enough.

Current execution gate: Epic #14 and `docs/CURRENT_DIRECTION.md`.


The target is **not** a field of tiny colored dashes.

MicroC0re should feel like observing an alien-but-biologically-grounded ecosystem through a deliberately pixelated scientific instrument.

## Visual hierarchy

At normal zoom the viewer should immediately read:

1. chemical landscape / resource patches;
2. moving microbial silhouettes;
3. lineage differences;
4. local clusters and collisions.

At close zoom the viewer should additionally read:

- outer wall / membrane;
- cytoplasm;
- nucleoid-like internal marks;
- animated flagella;
- short pili / fimbriae;
- growth / body proportions;
- selected-cell phenotype data.

Later organism classes may add cilia, pseudopodia, vacuoles, engulfment membranes, spores, extracellular matrix, and other morphology where biologically appropriate.

## Pixel strategy

The chemistry layer may remain a low-resolution texture, but that **does not by itself define the final pixel-art style**.

The organism pipeline must move from procedural vector-like drawing to deliberate low-resolution sprite/sprite-part design:
- controlled pixel clusters;
- limited palettes and coherent color ramps;
- intentional outlines / selective outlines;
- no accidental smoothing;
- key-pose/frame animation rather than arbitrary continuous line deformation;
- silhouette readability first;
- integer-friendly presentation at normal zoom.

The simulation remains continuous. Rendering may quantize/pixelate presentation, but must never feed that quantization back into biology.

Reference principles:
- Lospec: pixel art depends on deliberate pixel-level construction, not merely low resolution.
- PixelJoint/Cure: pay attention to pixel clusters, controlled AA, jaggies, banding, noise and palette discipline.

Primary tasks: #15 and #18.

## Performance architecture

Performance is now a product requirement, not a later polish step.

Baseline contract:
- target 120 FPS during normal microscope inspection;
- 60 FPS development floor;
- organism simulation tick and render FPS are separate;
- explicit far/mid/near/macro LOD;
- off-screen culling;
- no close-up appendage cost for distant organisms;
- profile simulation, chemistry, texture upload, organism rendering, appendages and HUD separately;
- use cached/batched sprites or MultiMesh2D where profiling shows it helps.

Observed close-zoom 5–8 FPS is a blocker. See #17.

The CPU reference simulation remains useful for validation even if later rendering/chemistry paths use GPU acceleration.

## Camera / inspection

Required microscope controls:
- wheel: zoom toward cursor;
- RMB/MMB drag: pan;
- WASD / arrows: pan;
- click: inspect nearest organism;
- F: fit full dish;
- SPACE: pause;
- R: restart same deterministic seed;
- N: next seed;
- 1/2/3/4: simulation speed 1x / 2x / 4x / 8x.

## Design references

### The Bibites
Useful ideas:
- appearance generated from genes;
- energy and digestion matter;
- mutations and natural selection are continuously visible;
- lineages can develop distinct behavior and morphology.

MicroC0re is not copying Bibites' creature design or neural architecture; the useful principle is that genotype should affect both behavior and appearance.

### Thrive — Microbe Stage
Useful ideas:
- membrane and cell parts remain legible during play;
- flagella / pili have gameplay meaning;
- compounds and ATP create visible resource pressure;
- zooming into a microbe should reveal more biological structure.

MicroC0re differs by being primarily an autonomous generative ecosystem rather than a player-designed microbe game.


### Biogenesis
Useful ideas:
- organisms expose function through visible morphology/color;
- descendants inherit a visual genetic structure with mutations;
- metabolism, environment, mutation and ecosystem feedback are all part of the same simulation.

MicroC0re should take the same readability principle but use a more microscopic, membrane/appendage-oriented visual language rather than colored line-segment organisms.

### Lenia / Flow-Lenia
Useful ideas:
- continuous fields can create highly organic emergent motion and morphology;
- self-organization can be visually beautiful without authored animation.

Reaction-diffusion / continuous-automata experiments remain a separate layer from the explicit bacterial agents so we do not conflate mathematical creatures with literal bacteria.


## Pixel-art research notes

Useful specialist references:
- Lospec “Pixel Art: Where to Start”: https://lospec.com/articles/pixel-art-where-to-start/
- PixelJoint / Cure “The Pixel Art Tutorial”: https://pixeljoint.com/forum/forum_posts.asp?TID=11299
- itch.io bacteria + Pixel Art browsing: https://itch.io/games/tag-bacteria/tag-pixel-art
- Microscope (Schkuey): https://schkuey.itch.io/microscope

These are references for process/readability and examples of low-resolution microbe presentation, not assets to copy.
