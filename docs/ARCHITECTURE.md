# Architecture

## Core idea

MicroC0re uses a **hybrid agent/continuum** architecture.

- Organisms are discrete agents with geometry and internal state.
- Chemistry is stored in continuous-looking scalar fields sampled from grids.
- The renderer observes snapshots of both.
- The simulation uses a fixed timestep and seeded randomness.

```text
       sources / reactions
               |
               v
+------------------------------+
|  scalar chemical fields      |
| nutrient / waste / signals   |
+------------------------------+
       ^                 |
 uptake|                 |sample
       |                 v
+------------------------------+
| discrete organisms           |
| rods / metabolism / sensing  |
+------------------------------+
       |
       | state snapshot
       v
+------------------------------+
| renderer / debug UI          |
| pixel microscope             |
+------------------------------+
```

## Directories

### `src/simulation/`
Pure simulation code:
- scalar fields;
- organisms;
- contact mechanics;
- metabolism;
- chemotaxis;
- reaction modules;
- deterministic stepping.

It must be runnable with `--headless`.

### `src/app/`
Godot-facing presentation:
- scene entry point;
- debug rendering;
- later camera, pixel viewport, shaders, UI.

It may read simulation state but should not mutate biology through rendering code.

### `tests/`
Headless scripts that exercise invariants and deterministic scenarios.

## Fixed-step loop

The app accumulates frame time but advances biology in constant-size ticks.

```text
render frame delta
      |
      v
accumulator += delta
      |
      +--> while accumulator >= fixed_dt:
      |        simulation.step(fixed_dt)
      |        accumulator -= fixed_dt
      |
      v
render latest state
```

This makes biology independent from display FPS.

## Simulation ordering for v0.1

A tick is conceptually:

1. inject environmental sources;
2. diffuse/decay scalar fields;
3. sample local nutrient history;
4. update run/tumble motility;
5. consume nutrient;
6. update energy and growth;
7. integrate movement and boundaries;
8. divide or die;
9. resolve mechanical overlaps iteratively;
10. accumulate waste / bookkeeping.

Ordering is explicit because changing it can change emergent behavior.

## Scaling strategy

Initial contact checks may be O(N²) for clarity.

Once profiling establishes a bottleneck:
- partition world into uniform spatial buckets;
- query only nearby rods;
- sort candidate IDs before resolving contacts so deterministic order is preserved.

Chemical grids can later move to compute shaders or GPU textures, but only after a CPU reference implementation exists for validation.
