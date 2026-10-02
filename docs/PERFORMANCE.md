# Performance budget

This document is the measurement contract for the visible MicroC0re prototype.

## Targets

Baseline scene:
- 1280x720 window;
- 640x360 internal canvas;
- biological simulation tick = 60 Hz;
- chemistry = 30 Hz;
- field texture upload = 20 Hz.

Performance targets:
- normal inspection target: 120 FPS;
- development floor: 60 FPS;
- no visual feature is accepted based on appearance alone if it pushes the agreed baseline below the floor.

## Measured baseline before optimization pass 2

Maintainer workstation, Godot 4.7.1, headless benchmark before the 60/30 Hz + tighter broad-phase pass:

- 100 agents: 5.675 ms/tick, 176.2 ticks/s at 120 Hz test cadence;
- 500 agents: 51.762 ms/tick, 19.3 ticks/s;
- 1,000 agents: 172.784 ms/tick, 5.8 ticks/s.

This proved the bottleneck was in the simulation kernel, not only the visible renderer. The next benchmark must be compared against these numbers qualitatively, but note that the benchmark cadence is now the intended 60 Hz biological step.

## Current renderer strategy

- full-screen background is a tiled cached pixel texture;
- chemistry is one cached ImageTexture draw;
- organisms are culled against the current camera view;
- far LOD uses a single tiny rectangle per visible organism;
- mid/near LOD uses cached 32x20 pixel-art atlas textures;
- appendages are baked into cached atlas frames, not rebuilt as polylines every frame;
- orientation is quantized to 32 visual directions;
- lineage colors are quantized to a fixed palette;
- rod contact broad-phase uses a spatial hash.

## Runtime HUD timings

The HUD reports:
- FPS;
- simulation time spent per rendered frame;
- chemical texture upload time;
- draw time;
- visible organisms;
- far-LOD count;
- sprite-LOD count;
- dividing / adhering / lysing organism counts.

These are coarse wall-clock measurements intended to identify bottlenecks quickly.

## Headless simulation benchmark

Run:

```powershell
./scripts/run_benchmark.ps1
```

The benchmark measures 100, 500 and 1,000 starting agents at the 60 Hz biological timestep and reports a real-time factor against 60 ticks/s.

Record results here before claiming a simulation optimization.

## Render test checklist

For each important renderer change, inspect:
1. fit view;
2. heavy zoom-out;
3. normal ecosystem view;
4. close zoom on a cluster;
5. close zoom during division / adhesion / lysis;
6. population after several generations.

Record:
- population;
- zoom;
- FPS;
- sim ms;
- field ms;
- draw ms.

## LOD policy

Far:
- constant-screen-size organism mark;
- no sprite animation;
- no appendage detail.

Mid:
- cached pixel sprite;
- reduced appendage class;
- no extra procedural detail.

Near / macro:
- cached animated pixel sprite with phenotype-derived size/appendage class;
- no additional per-frame vector flagella geometry.

Close zoom must not become more expensive merely because pixels are displayed larger.

## Future optimization candidates

Only pursue after profiling:
- MultiMesh2D / batched quads for far and mid LOD;
- GPU chemical field update;
- lower-frequency simulation for far-off-screen ecology partitions;
- dirty-region field texture updates;
- worker-threaded CPU chemistry if deterministic behavior can be preserved.

Do not optimize blindly.
