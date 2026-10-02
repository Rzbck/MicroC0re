# Optimization architecture — scalable MicroC0re

This document is the long-term performance plan for MicroC0re. It is deliberately broader than the current prototype so agents do not repeatedly rediscover the same optimization path.

The guiding rule is:

> Preserve the biological model and determinism first; optimize representation, scheduling, neighborhood search, rendering and hardware use around it.

Do not apply every technique at once. Every phase is gated by measurements.

---

## 1. Performance model

MicroC0re has four fundamentally different workloads:

1. **Agent state** — movement, sensing, metabolism, growth, lineage and life-cycle state.
2. **Short-range mechanics** — rod contact, adhesion and later local attacks/engulfment.
3. **Continuum fields** — nutrient, waste, signals, toxins and reaction-diffusion.
4. **Presentation** — camera, pixel sprites, chemical texture and HUD.

They should not be forced to run at the same frequency.

Current intended desktop cadence:

- presentation: target 120+ FPS;
- biological agent step: deterministic 60 Hz;
- contact mechanics: 60 Hz;
- chemical diffusion/source update: 30 Hz;
- chemical display texture upload: 20 Hz;
- slower metabolic/regulatory processes may later run at 10–20 Hz if validation shows no meaningful loss.

This is a **multirate simulation**, not a render-frame-driven simulation.

Reference precedent: PhysiCell explicitly tracks different next-update times for mechanics, cellular processes and output; BMX also uses timescale partitioning in a hybrid cell/continuum model.

---

## 2. Measure before changing architecture

Required measurements:

### Headless kernel
- ms/tick;
- ticks/s;
- real-time factor;
- pair candidates tested;
- true contacts resolved;
- neighbor-grid/list rebuild cost;
- chemistry cost;
- agent update cost.

Baseline population sizes:
- 100;
- 500;
- 1,000;
- later 5,000 / 10,000 once the native/data-oriented path exists.

### Visible renderer
- FPS;
- simulation ms/frame;
- field upload ms/frame;
- draw submission ms/frame;
- visible agents;
- culled agents;
- far/mid/near/macro LOD counts;
- draw calls when available.

Use:
- MicroC0re runtime timers;
- Godot Profiler;
- Godot Visual Profiler;
- NVIDIA Nsight Graphics when GPU-side uncertainty remains.

Godot's own performance guidance emphasizes measurement/profile-first optimization.

References:
- https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/debug/the_profiler.html

---

## 3. Agent memory layout — highest-value CPU refactor

### Current prototype weakness

The current kernel keeps each bacterium as a GDScript RefCounted object and accesses many values through Variant/property dispatch.

That is convenient but poor for a large hot loop.

### Target: Structure of Arrays (SoA)

Move hot state into dense packed arrays:

```text
position_x[] / position_y[]  or PackedVector2Array
angle[]
length[]
radius[]
energy[]
age[]
generation[]
parent_id[]
lineage_id[]
flags[]
division_progress[]
lysis_progress[]

gene_speed[]
gene_chemotaxis[]
gene_uptake[]
gene_growth[]
gene_size[]
gene_tumble[]
gene_adhesion[]
...
```

Use:
- `PackedFloat32Array`;
- `PackedInt32Array`;
- `PackedByteArray`;
- `PackedVector2Array` where it wins in actual profiling.

Godot documents packed arrays as tightly packed storage that reduces memory usage; contiguous packed state is also the right shape for future C++/SIMD/GPU transfer.

Reference:
- https://docs.godotengine.org/en/stable/classes/class_packedfloat32array.html

### Dense indices + stable IDs

Simulation index and biological identity must be separate.

Use:
- dense index for hot loops;
- immutable stable ID for lineage/replay/UI;
- `id -> dense index` lookup only outside the hottest loops.

Removal policy:
- swap-remove dead agents from dense storage;
- update the ID lookup;
- avoid shifting large arrays.

Preallocate expected capacity to reduce allocation spikes.

---

## 4. Randomness that survives parallelism

A single sequential RNG makes results depend on iteration order and becomes a barrier to multithreading/GPU work.

Long-term target: **counter-based RNG**.

Conceptually:

```text
random = RNG(seed, tick, agent_id, channel, sample_index)
```

That means a random sample is a deterministic function of identity/time, not of which thread happened to execute first.

Use separate channels for:
- tumble decision;
- angular perturbation;
- mutation;
- division geometry;
- phenotype initialization;
- future attack/adhesion stochasticity.

Philox / Random123 is the reference design: counter-based generators are stateless, parallel-friendly, vectorizable, and provide many independent streams.

References:
- https://random123.com/
- https://www.thesalmons.org/john/random123/papers/random123sc11.pdf

Do not replace RNG in the middle of a released deterministic replay format without versioning the simulation.

---

## 5. Short-range interactions — linked cells + Verlet lists

### Phase already implemented

The current rebuild branch uses a flat linked-cell grid:
- fixed grid head array;
- next-index array;
- no Dictionary/Vector2i allocation in the hot broad-phase;
- squared center-distance rejection before capsule segment math.

This is the right immediate direction.

### Next target: half Verlet neighbor list

For short-range mechanics, borrow the standard molecular-dynamics strategy:

1. build spatial bins;
2. build a **half neighbor list** so each pair appears once;
3. include true interaction radius + a small **skin distance**;
4. reuse the list for several ticks;
5. rebuild only when an agent has moved enough to invalidate the skin.

This trades occasional list construction for much cheaper mechanics steps.

LAMMPS uses this pattern extensively. It also notes that regular bins give near-linear scaling for short-range interactions, that half lists avoid duplicated pairs, and that a skin lets the list be reused between rebuilds.

References:
- https://doc.lammps.org/stable/Developer_par_neigh.html
- https://docs.lammps.org/stable/neigh_modify.html

### Precomputed stencil

Do not loop over a full square of bins if corner bins can never intersect the interaction cutoff.

Precompute integer bin offsets once for each relevant cutoff class.

Later, if cells become strongly polydisperse:
- use multiple cutoffs / bin classes;
- do not make every tiny bacterium search according to the largest organism in the ecosystem.

LAMMPS has a similar "multi" strategy for variable cutoffs.

### Cache capsule geometry

Once per mechanics tick, compute and store:
- axis x/y;
- segment start/end;
- broad-phase radius;
- AABB if needed.

Do not recompute `sin/cos`, axes and endpoints for every candidate pair.

### Avoid square roots

Use squared distances for rejection.

Only compute `sqrt()` when a true contact/adhesion correction needs a normalized direction.

---

## 6. Mechanical solver quality per unit cost

The current contact resolver is qualitative.

Two viable long-term paths:

### A. Overdamped bacterial mechanics
Biologically natural for microscopic colonies:
- contact force;
- drag;
- torque;
- position/orientation update in an overdamped regime.

This matches the style of many bacterial colony models.

### B. XPBD-style constraints
For robust interactive mechanics:
- contact/adhesion constraints;
- compliance;
- fewer solver iterations;
- stiffness less dependent on timestep/iteration count than classic PBD.

Reference:
- Macklin et al., XPBD: https://matthias-research.github.io/pages/publications/XPBD.pdf

Do not switch solvers just because XPBD is fashionable; compare:
- numerical stability;
- colony morphology;
- pair count;
- iterations;
- ms/tick.

---

## 7. Multirate biology

Not every cell subsystem needs 60 updates/s.

Candidate scheduling:

### 60 Hz
- position/orientation integration;
- run/tumble state;
- short-range mechanics;
- visible division/lysis progress.

### 20–30 Hz
- chemical sensing filter;
- nutrient uptake;
- waste exchange;
- high-level motility decisions.

### 10–20 Hz
- growth bookkeeping;
- regulatory networks;
- quorum logic;
- non-urgent gene expression;
- lineage statistics.

### Event-driven
- mutation only at division;
- lineage creation only at division;
- death transition only when crossing threshold;
- conjugation setup only when contact criteria become true.

Each decimation requires an A/B validation test against the higher-frequency reference.

---

## 8. Continuum chemistry

### Current scale

At 96x64, the field is tiny. A well-written CPU solver is adequate.

Current optimizations:
- packed Float32 arrays;
- fused row/index math;
- chemistry at 30 Hz;
- display texture upload decoupled at 20 Hz.

### CPU scaling path

Before GPU:
- fuse source/decay/reaction operations when mathematically safe;
- precompute static source masks;
- parallelize independent rows using `WorkerThreadPool`;
- double-buffer field values;
- avoid per-cell object calls.

Godot exposes `WorkerThreadPool.add_group_task()` for distributing indexed work across worker threads.

Reference:
- https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html

### Solver scaling path

Explicit Euler is simple and easy to validate but has a diffusion stability timestep bound.

If grid resolution / diffusion coefficients make substepping expensive, investigate:
- Crank–Nicolson;
- ADI/semi-implicit diffusion;
- operator splitting;
- finite-volume formulation if conservation becomes more important.

Implicit/semi-implicit methods can tolerate larger diffusion timesteps, but reaction-diffusion splitting can itself introduce accuracy/stability issues. Always validate against the reference explicit solver before replacing it.

References:
- Crank–Nicolson reaction-diffusion example: https://doi.org/10.1016/0898-1221(90)90217-8
- numerical methods review: https://doi.org/10.1016/0378-4754(83)90127-1
- operator-splitting stability caution: https://doi.org/10.1016/j.jcp.2004.09.004

---

## 9. CPU threading

Thread only workloads that can be made independent.

Good early candidates:
- chemistry rows / tiles;
- per-agent sensing/metabolism into output buffers;
- render-buffer construction;
- statistics/reductions.

Harder candidate:
- mechanics, because pairs write to two cells.

For deterministic parallel mechanics, prefer:
- thread-local correction buffers;
- deterministic reduction order;
- or spatial coloring / non-overlapping partitions.

Avoid mutex-per-contact designs; lock contention can erase the benefit.

Godot warns that engine objects are not universally thread-safe and recommends avoiding unsynchronized shared writes.

Reference:
- https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html

---

## 10. Native kernel via GDExtension

If GDScript remains the bottleneck after SoA + neighbor lists + multirate scheduling, move only the hot kernel to C++.

Keep in GDScript:
- app lifecycle;
- UI;
- camera;
- debug tooling;
- configuration;
- artistic systems that are not hot.

Move to C++ GDExtension:
- SoA state;
- cell-grid / Verlet list;
- capsule pair math;
- metabolism/motility hot loops;
- counter-based RNG;
- chemistry if CPU;
- snapshot/benchmark functions.

Advantages:
- native compiled loops;
- SIMD-friendly memory;
- explicit threading;
- less Variant/property overhead;
- same Godot project without rebuilding the engine.

Godot documentation explicitly describes GDExtension/C++ as the highest-performance scripting option while allowing it to be mixed with GDScript.

References:
- https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/about_godot_cpp.html
- https://docs.godotengine.org/en/stable/tutorials/scripting/cpp/index.html

### Native migration gate

Do not start C++ just because it sounds faster.

Start when:
1. the GDScript benchmark is well-profiled;
2. data layout has already been designed;
3. the target population cannot meet real-time after algorithmic fixes;
4. a headless equivalence suite exists.

---

## 11. Rendering at thousands of organisms

### Immediate baseline

Current rebuild:
- culls off-screen organisms;
- uses far/sprite LOD;
- uses cached atlas textures;
- does not procedurally rebuild flagella geometry each frame.

### Next rendering architecture: chunked MultiMesh2D

For thousands of visible organisms:
- one atlas;
- one shader/material;
- MultiMeshInstance2D or RenderingServer MultiMesh;
- per-instance transform;
- per-instance lineage color;
- per-instance custom data encoding atlas frame/state/phenotype class.

Godot's MultiMesh can draw very large numbers of instances in very few draw calls. MultiMesh itself does not individually cull instances, so split the world into **spatial chunks**, each with its own MultiMesh/visibility region.

References:
- https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- https://docs.godotengine.org/en/latest/classes/class_multimeshinstance2d.html

### Bulk buffer update

Do not call per-instance setters thousands of times if avoidable.

Build one contiguous instance buffer and call:
- `RenderingServer.multimesh_set_buffer()`;
- or `multimesh_set_buffer_interpolated()` for previous/current states.

Godot documents the 2D buffer layout and supports transform + color + custom data in one packed buffer.

Reference:
- https://docs.godotengine.org/en/stable/classes/class_renderingserver.html

### Render interpolation

Keep previous and current simulation transforms.

At render time:
- interpolate visually;
- never alter simulation state.

Godot supports MultiMesh interpolation in 2D.

Reference:
- https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html

---

## 12. GPU compute — later, not automatically better

Godot supports compute shaders through RenderingDevice, but compute shaders require a RenderingDevice renderer (Forward+ or Mobile), not the GL Compatibility renderer currently used by the project.

Reference:
- https://docs.godotengine.org/en/latest/tutorials/shaders/compute_shaders.html

### Important architectural warning

Do **not** put chemistry on GPU while reading the full field back to CPU every biology tick.

GPU -> CPU synchronization/readback can destroy the speedup. Godot's compute documentation explicitly warns that immediate synchronization stalls the CPU and recommends delayed/asynchronous use where possible.

Therefore:

### CPU canonical mode
Best for:
- deterministic reference;
- tests;
- moderate populations;
- easy debugging.

### GPU accelerated mode
Makes sense when:
- field resolution is much larger;
- many chemical channels exist;
- agent simulation can also consume field data on GPU;
- readback is sparse/infrequent.

Potential GPU pipeline:
1. SoA agent storage buffer;
2. spatial binning / prefix sum;
3. neighbor/contact kernels;
4. field diffusion/reaction kernels;
5. agent sampling and metabolism kernels;
6. MultiMesh/instance buffer written directly for render;
7. only small statistics/events read back to CPU.

This is a future high-scale path, not v0.2.

---

## 13. Research precedent from biological simulators

MicroC0re is not inventing the hybrid architecture.

### BMX
BMX uses a hybrid discrete-cell / continuum-chemical model, GPU acceleration, spatial particle operations, AMReX, time-scale partitioning and CPU/GPU portability for large bacterial colony simulation.

Reference:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC10382537/

### CellModeller
CellModeller uses GPU acceleration for bacterial colony modeling and represents bacteria as rigid capsules that grow and divide.

References:
- https://pubmed.ncbi.nlm.nih.gov/23651288/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC6170782/

### PhysiCell
PhysiCell uses multi-rate updates and OpenMP parallelism and reports approximately linear scaling in cell count for its intended workloads.

Reference:
- https://pmc.ncbi.nlm.nih.gov/articles/PMC5841829/

### BioDynaMo
BioDynaMo is a high-performance agent-based platform explicitly focused on hardware utilization, memory layout, allocation and scalable parallel execution.

References:
- https://pubmed.ncbi.nlm.nih.gov/34529036/
- https://doi.org/10.1145/3572848.3577480

These systems validate the overall direction:
- spatial locality;
- dense data;
- multirate stepping;
- parallelism;
- GPU only where data stays on GPU long enough to benefit.

---

## 14. Storage, replay and long-running art generation

Do not store every rendered frame as simulation state.

### Canonical run identity
Store:
- simulation version;
- model/schema version;
- seed;
- parameter preset;
- initial conditions.

### Checkpoints
Periodically save a compact binary snapshot:
- dense agent arrays;
- field arrays;
- next stable ID;
- simulation tick;
- lineage metadata.

Use packed/binary data, not large JSON blobs, for bulk numeric state.

### Event stream
Store rare semantic events:
- birth/fission;
- death/lysis;
- mutation summary;
- conjugation;
- predation;
- user parameter changes.

### Replay strategy
For deterministic CPU mode:
- seed + initial state + parameter/event changes;
- optional periodic checkpoints for fast seek.

For future GPU approximate mode:
- checkpoints become authoritative because cross-GPU bitwise determinism may not hold.

---

## 15. World scaling / chunks

The current simulation domain is small and finite.

For much larger worlds:
- partition ecology into simulation chunks;
- chunk-local linked-cell/Verlet data;
- activate mechanics at full rate only where populations are present;
- keep chemistry chunked with halo cells;
- use distance/interest-based simulation frequency only if conservation/behavior tests accept it.

Visual "infinite microscope" and physically simulated infinite world are separate features.

Do not simulate empty space at full resolution.

---

## 16. Recommended implementation order

### P0 — now
- [x] multirate separation: 60 Hz biology / 30 Hz chemistry / 20 Hz field display;
- [x] flat linked-cell grid;
- [x] cheap center-distance rejection;
- [x] visible LOD + culling;
- [x] cached pixel atlas;
- [x] benchmark + HUD timers.

### P1 — next measurements
- [ ] record new 100/500/1000 benchmark;
- [ ] add pair-candidate / true-contact counters;
- [ ] precompute neighbor-bin stencil;
- [ ] cache capsule geometry once per mechanics tick;
- [ ] tune bin size from measured candidate counts.

### P2 — major CPU architecture
- [ ] SoA PackedArray agent store;
- [ ] dense indices + stable IDs;
- [ ] swap-remove/free-list lifecycle;
- [ ] counter-based RNG;
- [ ] Verlet half-neighbor list with skin;
- [ ] decimate slower metabolism/regulation where validated.

### P3 — rendering scale
- [ ] chunked MultiMeshInstance2D;
- [ ] atlas shader via INSTANCE_CUSTOM/custom data;
- [ ] one bulk instance-buffer update per chunk;
- [ ] previous/current transform interpolation.

### P4 — multicore CPU
- [ ] WorkerThreadPool chemistry;
- [ ] staged parallel per-agent update;
- [ ] deterministic mechanics reduction if needed.

### P5 — native CPU
- [ ] GDExtension C++ kernel if P2/P4 GDScript cannot hit population target;
- [ ] SIMD / OpenMP inside native kernel where profiling supports it.

### P6 — GPU high-scale path
- [ ] evaluate Forward+ renderer migration;
- [ ] compute chemistry prototype;
- [ ] no synchronous full readback;
- [ ] only move agent mechanics/chemistry to GPU as a coherent pipeline;
- [ ] retain CPU reference mode.

---

## 17. Optimization anti-patterns

Never:
- optimize from FPS alone without timing subsystems;
- make render FPS dictate simulation timestep;
- use O(N²) contact checks at large N;
- rebuild neighbor data every tick if a skin can safely reuse it;
- allocate Dictionaries/temporary Arrays inside the tightest pair loops;
- call thousands of engine-object methods when one packed buffer can do the same work;
- move one stage to GPU if every tick immediately reads all its data back;
- parallelize a sequential RNG stream and call the result deterministic;
- reduce update frequency without an A/B validation test;
- trade biological coherence for speed silently;
- store every frame when seed/checkpoint/event replay can reconstruct a run.

---

## 18. Performance definition of done

A performance change is accepted only when the PR contains:

1. scenario and population;
2. before measurement;
3. after measurement;
4. correctness/determinism result;
5. memory effect if meaningful;
6. explanation of any numerical/model change;
7. rollback path if the optimization causes artifacts.

Speed without model integrity is not an optimization for MicroC0re.
