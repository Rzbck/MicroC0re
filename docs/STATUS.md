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
- #62 cross-feeding / quorum biofilm / dormancy
- #63 flagellate bacterivore / tri-trophic grazing

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
- #33 phenotypic switching / dormancy / division of labor
- #34 quorum sensing / EPS biofilm / cooperative-cheater evolution
- #36 lineage tree / ancestry history / emergent phenotype clusters
- #42 metabolic cross-feeding
- #43 mature biofilm/EPS ecosystem engineering
- #50 pH / temperature / redox / toxicity
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
- fungal enzyme field converts detrital substrate into dissolved nutrient/exudate around real hyphal tips;
- new exudate field links microalgae, phototrophic bacteria, decomposers and heterotrophic uptake;
- deterministic succession cycle now alternates local resource pulses, washout and organic-fall events;
- disturbances act on biome fields, creating bloom/recolonization/scavenger opportunities without scripted species replacement;
- new quorum field makes biofilm/EPS production density-responsive;
- EPS now slows predator handling and boosts local exudate capture, making matrix a functional niche/refuge;
- bacteria can reversibly enter dormancy under low resource and wake when local dissolved resource returns;
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
- renderer exposes nutrient, waste, oxygen, producers, EPS, detritus and damage through sparse shader-driven local material over a dedicated water layer.

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
- small flagellate-like bacterivores, forming an intermediate prey/predator tier between bacteria and larger ciliates/amoebae;
- evolving microalgae-like producers with light-driven oxygenation, exudates, division and lysis;
- evolving yeast-like decomposers with detritus consumption, mineralization, budding and lysis.

### Environmental evolution
- bacterial lysis releases bounded extracellular DNA fragments;
- heritable competence can trigger under stress, costs energy, and enables lineage-weighted trait recombination;
- transformation is separate from plasmid conjugation and fragments decay/drift on the slow biome cadence.

### Predation / death
- bounded lineage-specific phage cloud packets create staged infection, lysis and viral nutrient shunting;
- phage amplification is host-driven, adding kill-the-winner pressure while EPS/dormancy provide partial refuges;
- visible bacterial adhesion/size/EPS traits now increase predator handling difficulty and can permit escape;
- amoeba/ciliate/flagellate capture genes counter prey handling defence, creating an explicit first coevolution loop;
- amoebae and ciliates can bias search toward damage plumes when direct prey is absent;
- ciliates graze bacteria, microalgae and yeast-like decomposers;
- amoebae graze bacteria, microalgae, decomposers and suitably small ciliates;
- active predation leaks detritus/damage cues into the local biome;
- low-energy amoebae/ciliates visibly weaken and slow before terminal lysis;
- starved amoebae/ciliates enter a staged lysis/death state instead of disappearing instantly;
- predator death renders fragments/fade and recycles biomass;
- a regression test now verifies ciliate feeding remains attached to non-bacterial prey across frames.

### Shader biome / event asset rebuild
- audit found the shader quads had no texture; Godot therefore did not build Polygon2D UV vertex data, collapsing mask sampling to one corner;
- quads now use a 1x1 opaque UV-driver texture so the shaders receive the intended 0..1 UV coordinates;
- producer logistic growth now requires existing biomass; empty cells can no longer spontaneously become producer mat;
- producer material spreads slowly through a small diffusion term and can be seeded by explicit microalgae / phototrophic bacteria;
- rejected the full-screen 4x4 animated motif atlas after maintainer video review;
- dedicated water shader provides a stable low-contrast aqueous base;
- dedicated biome material shader consumes producer/detritus/EPS/damage/oxygen/nutrient/waste masks;
- all biome/event source pixels use the same 0.25-world-unit scale as organism atlases;
- masks refresh at 2 Hz; shader pattern coordinates are stable and do not crawl;
- water remains dominant and ecological material stays sparse/local;
- event FX atlas is 7x7 at organism source-pixel scale;
- #57 remains the GPU-resident field/mask path.

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


## Visual language rebuild — active 2026-10-03

First structural pass:
- root stretch changed from `canvas_items/expand` to `viewport/keep` with integer scale mode;
- close organism atlases now share the documented 0.25-world-unit source-pixel scale;
- removed continuous radius/gene-based texture resizing from current organism renderers;
- overview/full-sprite LOD now uses deterministic binary dithering rather than alpha crossfade;
- far bacteria are separate integer-screen-pixel silhouettes with quantized orientation;
- full organism orientations reduced to 8 stable directions to reduce pixel shimmer;
- feeding/reproduction/death atlas frames now follow interaction progress where available;
- generic biological FX remain accents and no longer rescale independently.

Next visual gate: replace shader speckle with coherent biome clusters and simplify interaction VFX hierarchy before adding further guilds.


Second visual-language pass:
- biome shader no longer samples per-pixel hash noise as the visible unit;
  producers, EPS, detritus, damage and exudate now render as stable multi-pixel
  material clusters on the shared source grid;
- dissolved nutrient/oxygen/waste are demoted to rare paired-pixel notation;
- generic predator pursuit/digestion and starvation icon soup removed from the
  normal view;
- active feeding now reads as progress-staged contact geometry driven by the
  simulation's capture progress;
- inspector local-biome line now explains qualitative niche/resource state
  instead of dumping six unlabeled scalar values.


Third visual-language pass:
- mouse-wheel zoom is now smoothly interpolated while preserving the cursor's
  world anchor;
- bacterial hue is reserved for lineage; guild is read from morphology instead
  of a second color blend;
- selection reticle no longer emits a decorative moving wake;
- deterministic succession events receive a brief local pixel front so abrupt
  biome changes have an observable cause;
- late lysis fragments shift toward detrital brown, visually handing death into
  the recycling layer.


## Video-driven visual correction — 2026-10-03 18:09

Based on the maintainer capture rather than code inspection alone:
- replaced near-black water with readable microscope water;
- removed plus-sign biome language and replaced it with irregular connected
  producer/EPS/detritus/damage/exudate patches;
- strengthened biome-mask presentation without changing ecology rules;
- reduced neon organism modulation, especially producers/decomposers;
- reduced auto-focus zoom and shrank/faded the inspector;
- simplified event accents so body state + environmental handoff remain primary.


## Inspector / hypha readability correction
- inspector text restored to readable 7-8 internal pixels; the previous 5px body
  size was illegible after integer presentation scaling;
- inspector remains compact but is slightly wider so words no longer collapse;
- hyphal art reduced from thick orange cable-like branches to one-pixel fungal
  filaments with distinct tip/junction clusters.


## #64 open-ended genome foundation
- bacteria now carry bounded variable-length ecological module programs;
- modules can duplicate, delete, insert, rewire sensors, flip regulation and
  rarely change function during vertical reproduction;
- local nutrient/exudate/detritus/light/quorum/damage/energy/oxygen signals
  regulate module expression;
- bacterial ecological role is derived from current expression instead of being
  permanently locked to one guild;
- module expression and genome complexity have explicit energetic costs;
- natural transformation can merge donor functional modules;
- conjugation has a rare chromosomal-module recombination path;
- inspector exposes current emergent ecotype label + compact ecotype hash.


## Isometric living-world pivot — #65
- main presentation moved to fullscreen Node3D with orthographic/isometric camera;
- RMB orbit, MMB pan, wheel zoom, WASD pan, Q/E rotation, F fit;
- deterministic mutable height field added with a water level;
- excavation removes real terrain mass and carried soil can be deposited elsewhere;
- slope relaxation conserves material and turns deposits into mounds;
- topography feeds back on movement through evolvable climb/burrow capability;
- every current organism family owns the same variable-length physical
  capability genome;
- visible 3D morphology exposes digging, oviposition potential, armor and
  below-surface burrow depth;
- legacy 2D microscope remains in-tree but is no longer the main scene.


## Cross-family physical recombination
- disappearing organisms can leave one bounded mobile capability cassette;
- cassettes are visible in the 3D world and decay after a short lifetime;
- every organism family can evolve an assimilation module;
- successful uptake merges the donor physical module into the recipient's
  variable-length capability genome;
- transfer is capped, local, deterministic and energetically costly.


## Pixel-isometric correction after captured fullscreen review

The first #65 presentation used native 3D primitives and an integer-scaled
1280x720 viewport. On a 1366x768 display that produced the visible black frame,
destroyed the established pixel-art organism language, flattened the apparent
terraforming, and reintroduced a permanent debug text block.

Correction:
- main scene is again a Node2D pixel renderer, but with a true 2:1 isometric
  projection over the living height field;
- all existing organism pixel atlases are reused instead of boxes/spheres;
- rotation is restricted to crisp 90-degree world turns so the isometric pixel
  geometry never shears/deforms;
- middle-drag pans, right-drag rotates in quarter turns, wheel zooms around the
  cursor, Q/E rotate and F fits the whole biome;
- the viewport now fills the physical fullscreen instead of preserving an
  integer-scaled 1280x720 black frame;
- always-on top-left debug text is removed; H toggles a small help panel;
- terrain tops and exposed sides are pixel-drawn, with cuts/fills colored from
  the difference against the seed terrain;
- excavation/deposition throughput was increased so mounds and pits become
  visibly legible on gameplay timescales;
- carried soil and active dig/deposit actions are visible as restrained pixel
  clusters attached to the acting organism.


## Live-session diagnostics / UI recovery — #66
- click-to-inspect restored in the pixel-isometric renderer;
- selecting an organism recenters/follows it and restores a compact readable
  inspector with ecology + physical capability state;
- compact top-right menu restored (pause, speed, fit, new seed, perf, help);
- RMB rotation now commits one 90-degree turn on release instead of repeatedly
  spinning while dragged; rotation preserves the current pan/focus;
- optional P overlay exposes FPS/process/draw/simulation cost and visible tile
  count;
- terrain environmental sampling is cached at 4 Hz and off-screen isometric
  tiles are culled before polygon drawing;
- local bounded session telemetry records every run;
- public GitHub publication is opt-in and posts only a strict allowlist to #66;
  usernames, hostnames, IP/MAC, paths, locale/location, exact GPU model and raw
  logs are never included.


## Telemetry publisher hotfix
- fixed the PowerShell Godot-version allowlist regex: the hyphen inside the
  character class formed an invalid reverse range (`.-+`) on Windows
  PowerShell;
- existing local `.microcore/telemetry/last-session.json` reports remain
  valid and can be published after pulling this commit without replaying the
  session.


## Telemetry publisher parser recovery
- recovered the complete publisher from the pre-hotfix revision after the first
  regex patch accidentally triggered JavaScript replacement-string `$'`
  semantics and duplicated the remainder of the PowerShell file;
- the Godot version regex is now valid and the publisher file is no longer
  duplicated/truncated;
- the previously recorded local session report is still reusable after pulling.


## Telemetry-driven terrain batching — session 2bbc866ed0204f23
The first real #66 session made the renderer bottleneck measurable:
- full-biome view: ~2776-2860 terrain tiles, ~4700-4840 draw calls,
  ~78-83 ms of immediate terrain drawing, 5-7 FPS;
- close view: ~480-535 tiles, ~950-1030 draw calls, ~23-25 ms drawing,
  11-13 FPS;
- simulation cost stayed comparatively stable at ~13-19 ms/tick.

Correction:
- terrain tops + exposed height faces are now emitted as one retained
  RenderingServer triangle array instead of thousands of CanvasItem polygon
  commands;
- ecological tile marks are emitted as a second triangle-array batch;
- camera pan/zoom/follow now transform the retained batch instead of rebuilding
  terrain geometry;
- geometry is rebuilt only for quarter-turn rotation or the 4 Hz terrain/ecology
  refresh;
- performance telemetry now records terrain batch rebuild time + triangle count;
- session publisher Markdown interpolation/code fencing fixed;
- menu gains EXIT TO DESKTOP;
- click selection radius increased from 22 px to 28 px.


## Pixel-isometric batch parser hotfix
- fixed the active renderer's `Transform2D` construction: Godot 4.7.1 has no
  `Transform2D(float, Vector2, Vector2)` overload;
- batch scale/origin are now assigned explicitly through the transform basis and
  origin, preserving the intended pixel-isometric pan/zoom behavior;
- CI now directly parses `src/app/pixel_isometric_world.gd` and the smoke test
  preloads the active pixel-isometric renderer + telemetry script, so a parser
  regression in the actual main renderer can no longer pass while only legacy
  renderers compile.


## Telemetry-driven population/simulation optimization — session 2165f5b63f76f882

The 465 s session showed the terrain batch worked but exposed the next bottleneck:
- initial full-biome draw fell from ~80 ms to ~3 ms and draw calls from ~4800
  to ~150-200;
- later the ecosystem produced 587-597 bacteria despite the documented 420
  safety ceiling, with total agents peaking at 621;
- simulation cost then climbed to ~100-109 ms/step and rendering those hundreds
  of full sprites rose to ~20-23 ms;
- the over-cap bloom was a real synchronous-division accounting bug: completed
  fissions early in the array checked only the partially built next population,
  ignoring survivors that would be appended later.

Optimization pass:
- bacterial fission now uses a net-birth budget computed from the starting live
  population, so a division wave cannot exceed the 420 CPU ceiling;
- high global bacterial crowding raises division energy cost smoothly instead of
  letting one bloom instantly occupy the whole view;
- ecological genome expression is now one module scan per bacterium/tick instead
  of repeated scans for six traits + guild + label + complexity;
- physical capability expression is one module scan per terrain-agent update;
- terrain/terraforming agent logic now runs at 15 Hz with dt-correct rates;
- bacterial contact mechanics reduced from 2x60 Hz to 1x30 Hz;
- visible app has an 18 ms simulation catch-up budget and refuses the old
  multi-step death spiral when the CPU cannot stay real-time;
- full-biome organism rendering now switches to one retained colored triangle
  batch below zoom 3.35; close zoom still uses the detailed pixel atlases;
- terrain visual batch refresh reduced from 4 Hz to 2 Hz;
- click selection tolerance increased to 38 px;
- telemetry now separates core simulation, terraforming agents, bacteria update,
  chemistry, mechanics, pair counts and far-agent batch population.


## 10k-agent architecture tranche 1 — telemetry session 7a0c1232e3da87b7

The latest 298 s session validated the population cap but showed the next scale
limits clearly:
- 452 total agents max, with bacteria stabilizing around the 420 cap;
- p50 simulation 15.7 ms, p95 41.76 ms;
- bacterial update reached ~25-26 ms near the cap;
- chemistry/slow-biome updates produced periodic ~30 ms spikes;
- detailed close rendering still reached ~15-17 ms around 420 bacteria, while
  the retained far batch stayed below 1 ms;
- requested x2/x4/x8 simulation speed was not measurable and the old accumulator
  policy discarded backlog, so acceleration could appear to do nothing.

This pass moves the CPU reference toward the #67 architecture:
- bacteria and other mobile agents now update at 30 Hz while rendering remains
  independent; chemistry runs at 15 Hz and slow biome at 5 Hz with dt-correct
  rates;
- scalar-field diffusion uses precomputed neighbour indices in flat packed
  arrays instead of rebuilding row/clamp topology for every cell/substep;
- hot local bacterial field reads use nearest-cell sampling, matching the
  existing nearest-cell uptake/write model and avoiding repeated bilinear reads;
- water flow and ambient light are cached on the field grid; trigonometric
  functions are evaluated per row/column cadence instead of per organism;
- predator bacterial prey search and extracellular-DNA competence search reuse
  the linked-cell spatial grid rather than scanning all bacteria;
- stable ID dictionaries replace repeated linear find-by-id scans during feeding
  and conjugation;
- ecological and physical module dictionaries use copy-on-write inheritance:
  daughters share immutable modules until an actual mutation/recombination;
- far-agent batching now remains active until zoom 6.2, keeping hundreds of
  organisms in a single retained triangle batch for most biome-scale views;
- terrain visual rebuild cadence reduced to 1 Hz pending chunk-dirty terrain
  batching;
- x1/x2/x4/x8 now accumulate requested simulation time correctly, use a bounded
  dynamic CPU budget instead of discarding almost all accelerated time, and
  telemetry reports requested versus achieved speed;
- the manual CPU benchmark now includes 2k and 5k seeded-agent probes with
  shorter measurement windows at the largest scales.

Still intentionally deferred to the next #67 tranches: chunk-dirty terrain
meshes, SoA agent storage/GDExtension hot kernels, worker-thread chunk jobs, and
GPU-resident fields/agents. Those require moving ownership of hot state rather
than layering unsafe threads/readbacks over RefCounted objects.


## Continuous scale gate
- headless CI now runs the CPU benchmark through 100 / 500 / 1000 / 2000 / 5000
  seeded bacteria after parser + smoke validation;
- the 2k/5k cases use shorter measurement windows so every performance commit
  exposes scale regressions without turning CI into a long soak test.
