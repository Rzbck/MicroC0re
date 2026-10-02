# Art direction — Living Microscope

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

The chemistry layer is a true low-resolution texture:
- 96 x 64 scalar samples in the current prototype;
- nearest-neighbor filtering;
- rendered as a single texture over the Petri world;
- refreshed independently from the render framerate.

This produces large readable chemical pixels when zoomed and avoids thousands of Canvas draw calls per frame.

Organisms remain continuous simulation objects but are rendered with:
- non-antialiased geometry;
- coarse silhouettes;
- discrete internal marks;
- nearest-filtered surroundings.

The renderer must never quantize the actual simulation state.

## Performance architecture

Current visible target:
- organism / movement simulation: 120 Hz fixed step;
- chemistry: 60 Hz deterministic sub-rate;
- field texture upload: 20 Hz;
- presentation cap: 144 FPS;
- rod contacts: uniform spatial hash, not global O(N^2).

The field texture update may become a compute shader later, but the CPU reference remains useful for validation.

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
