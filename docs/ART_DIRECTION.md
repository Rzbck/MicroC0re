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

## Locked prototype settings

Current implementation choices for the rebuild branch:
- internal render canvas: **640x360**;
- default window: **1280x720** (2x presentation);
- organism atlas cell: **32x20 px**;
- atlas animation: **4 frames**;
- visual orientation: **32 quantized directions**;
- lineage colors: fixed **8-color palette**;
- far LOD: constant-screen-size mark;
- mid/near LOD: cached atlas texture;
- background: repeating 32x32 pixel tile in screen space;
- chemistry: 96x64 nearest-filtered field texture.

These are prototype constraints, not permanent project limits. Change them only with a documented visual/performance reason.

## Biome material / shader contract

The rejected 4x4 full-screen motif atlas is **not** the baseline.

All visible biological/environmental art shares one source-pixel scale: **0.25 world units**. Organism atlases, biome shader pixels and biological-event FX use that same grid.

The environment is split into real game-art materials:
- **water shader**: always present, dark, low contrast, spatially stable grain, only a very slow continuous luminance drift;
- **biome material shader**: consumes slowly refreshed simulation masks and reveals sparse local producer, detritus, EPS, damage, oxygen, nutrient and waste material.

Rules:
- water remains visually dominant;
- most biome shader pixels are transparent;
- no global frame-swapping/tile animation;
- patches change because simulation fields accumulate/decay;
- producer/EPS/scavenger/death activity alters the fields that drive the art;
- CPU reference masks refresh at 2 Hz; #57 owns the GPU-resident path;
- biological-event FX use a compact 7x7 atlas at the same source-pixel scale.

Primary implementation: #61.


## Pixel strategy

The chemistry layer may remain a low-resolution texture, but that **does not by itself define the final pixel-art style**.

The organism pipeline now uses a first code-authored cached pixel atlas. It replaces per-frame procedural capsule/flagella drawing and is the baseline for further hand-authored sprite refinement.

The sprite/sprite-part design rules are:
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

The first atlas is intentionally simple. Its purpose is to establish the correct pipeline: deliberate pixels, cached frames, controlled palette, quantized orientation and LOD. Future visual refinement should replace pixel patterns inside that pipeline rather than return to smooth procedural line art.

## Performance architecture

Performance is now a product requirement, not a later polish step.

Baseline contract:
- target 120+ FPS during normal microscope inspection;
- 60 FPS development floor;
- biological simulation runs at a deterministic 60 Hz;
- chemistry currently runs at a deterministic 30 Hz;
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


### Shader geometry requirement

For shader-backed world polygons, a valid 1x1 opaque texture is intentionally assigned even when the shader does not sample `TEXTURE`. Godot's `Polygon2D` only builds/passes UV vertex data when a texture is valid. Removing this UV-driver texture collapses the biome mask sampling and is a rendering regression.


## Visual-language rebuild contract — 2026-10-03

The previous renderer violated its own source-pixel rule by scaling different
organism atlases with unrelated floating-point factors and by alpha-crossfading
overview markers and sprites.

The renderer now follows these hard rules:

- root presentation uses Godot `viewport` stretch with integer scaling;
- one biological source pixel is always **0.25 world units** in close sprites,
  event atlases, DNA, phages and hyphal assets;
- organism gene/radius values do **not** continuously rescale pixel textures;
  morphology changes belong in authored atlas classes/frames;
- the camera remains continuously zoomable, but source sprites only enter once
  the zoom reaches the range where their source pixels are readable;
- overview-to-sprite handoff uses deterministic per-organism ordered dithering:
  an organism is one representation or the other, never two translucent bodies;
- overview silhouettes use integer screen-pixel dimensions and 8-direction
  orientation;
- runtime sprite orientation is limited to 8 stable directions to reduce pixel
  shimmer until direction-specific authored atlas frames replace rotation;
- action progress drives feeding/reproduction/death key frames where those
  progress values exist; important actions must not merely loop unrelated FX;
- generic effect sprites are accents at the same source-pixel scale, never
  independently scaled pseudo-organisms.

This is the baseline for #15/#18/#60. Future visual work must improve authored
silhouettes and state frames without reintroducing fractional sprite scaling.
