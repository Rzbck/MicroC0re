# MicroC0re — AI handoff

This document is the operational handoff for a fresh ChatGPT/Codex/agent session. It should be sufficient to resume the project without asking the maintainer to reconstruct recent history.

## Repository / active branch

- Repository: `Rzbck/MicroC0re`
- GitHub Project: `MicroC0re` (#2)
- Active development branch: `rebuild/pixel-microscope-v0.2`
- Active PR: #19
- Latest **code** commit documented by this handoff: **`2222688b09e92c7d1b2c01d5095518fa94043b25`**
- Code commit title: **`Polish living microscope presentation`**
- The branch HEAD may be one or more documentation-only handoff commits newer than `2222688`; always fetch the branch and inspect `git log` before coding.
- Telemetry issue: #66
- Benchmark / smoke issue: #67
- Godot: 4.7.1
- Maintainer local project path: `E:\_Project\MicroC0re`
- Maintainer GPU used for local validation: NVIDIA GeForce RTX 5080

GitHub Project **Status** remains the canonical workflow state.

## Mandatory bootstrap for a fresh agent

Before choosing work:

1. Read `/AGENTS.md`.
2. Read `docs/CURRENT_DIRECTION.md`.
3. Read `docs/STATUS.md`.
4. Read this file completely.
5. Inspect PR #19 and the last commits on `rebuild/pixel-microscope-v0.2`.
6. Inspect issues #66 and #67 for the newest telemetry / benchmark evidence.
7. Read the relevant One-Page files:
   - `docs/one-pages/01_EVOLUTION_SPECIES.md`
   - `docs/one-pages/02_BIOME_SUCCESSION.md`
   - `docs/one-pages/03_SCALE_PERFORMANCE.md`
   - `docs/one-pages/04_MICROSCOPE_READABILITY.md`
8. For evolution work, also read `docs/EVOLUTION.md` and `docs/RESEARCH.md`.
9. For performance/GPU work, also read `docs/OPTIMIZATION_STRATEGY.md`.

Do not ask the maintainer to repeat history already present in GitHub.

---

# Current product direction

The project is an evolving living-microscope simulation, not a sterile benchmark.

The maintainer explicitly wants:

- organisms that keep evolving indefinitely;
- many visible species, not thousands of hidden ecotypes that all look the same;
- bidirectional ecology: organisms reshape the biome and the biome selects organisms;
- readable terraforming: it must be obvious who digs, who builds, what gets destroyed, and what later colonizes it;
- water, moisture, seasons and evolving terrain cover;
- readable pixel-art organisms, with front/back and behavior visible;
- no ugly generic cube/diamond replacement at ordinary populations;
- feeding, predation, division, lysis, dormancy, construction and destruction to be visibly animated;
- terrain that becomes visually rich: water, grass, shrubs, trees, rocks, relief, construction / erosion-like structures;
- optimization that preserves biology instead of deleting systems;
- real measured performance; requested x8 must never be reported as achieved x8 unless simulation-time / wall-time actually reaches it.

The microscope view should feel like artwork first. Debug overlays are useful for validation but are not the final product aesthetic.

---

# Important maintainer working style

The maintainer prefers direct implementation over long design lectures.

When work is clear:

- inspect current code / telemetry;
- make the change;
- push it;
- give a short explanation;
- provide a small PowerShell block only when local validation is required.

Do not spend multiple turns only theorizing.

For long tasks, send brief progress updates while working.

---

# Latest implementation state

## 1. Evolution / species

Current design separates:

- exact ecotype / genotype: fine-grained and potentially thousands;
- phenotype species: stable readable grouping;
- guild: broad trophic role;
- lineage: ancestry/history.

Recent changes include:

- phenotype-species identity cached as cold state;
- frequency-dependent anti-monoculture pressure;
- multi-species refugia / seed-bank behavior;
- predator carrying capacity separated from CPU safety guards;
- decomposer `gene_spore` and hyphal `gene_quiescence`;
- basal decomposer / hyphal dormancy with finite reserves and local wake-up;
- dormancy telemetry;
- stable species tint + bounded lineage tint variation;
- current HEAD increases phenotype-species trait bands from 3 to 4 and strengthens rare-species relief / dominant-species cost;
- current HEAD also uses stable species ID to choose small silhouette/body-mark variants.

Evolution must remain open-ended. Do not freeze mutation, HGT, transformation, predation, guild behavior or terraforming at high population merely to gain FPS.

## 2. Ecology / trophic system

Implemented guilds include:

- bacteria;
- protozoa / amoebae;
- ciliates;
- flagellates;
- microalgae;
- decomposer yeast-like organisms;
- hyphal colonies;
- phage clouds and extracellular DNA fragments.

Predator carrying capacity now follows ecological prey availability and is no longer identical to CPU guard values.

Current technical guards are deliberately above the normal current trophic range:

- protozoa: 48
- ciliates: 64
- flagellates: 128

Telemetry exposes live population / calculated trophic capacity.

## 3. Terraforming / biome succession

Persistent biome states:

- Open
- Producer
- Biofilm
- Detrital
- Fungal
- Anoxic
- Disturbed

Important corrections already made:

- `DISTURBED` is temporary and decays;
- old physical height changes remain, but do not permanently lock the ecological label;
- tiny distributed edits no longer automatically mark most of the map disturbed;
- current terraforming has separate fading action traces:
  - digging = darkened terrain;
  - building/depositing = warmer terrain;
  - traces are tinted toward the lineage color of the organism that performed the action;
- overlay exposes `dig` / `build` trace counts.

This was added specifically because the maintainer could not tell “who builds what / who destroys what”.

## 4. Hydrology / seasons / living cover

Implemented on the terrain grid:

- dynamic water depth;
- low-frequency water runoff between neighboring cells using soil+water surface height;
- persistent soil moisture;
- rainfall;
- evaporation;
- four-season climate cycle;
- wet / flooded habitat bias toward relevant biome states;
- terrain cover succession:
  - bare → grass → shrub → tree
  - persistent rocks;
- flooding, drought, disturbance and season can regress cover;
- living cover feeds producer biomass and oxygen;
- autumn returns litter to detritus;
- shrubs / roots / rocks increase resistance to excavation;
- hydrology runs at low cadence rather than 60 Hz;
- cover evolves slowly rather than every frame.

At HEAD `2222688`, presentation also includes:

- sparse animated water specular streaks;
- seasonal terrain palette shifts;
- larger layered pixel silhouettes for shrubs / trees / rocks;
- contact shadows and deterministic local visual variation.

Still missing / incomplete:

- explicit river-channel erosion/deposition driven by water flux;
- explicit organisms grazing trees/shrubs as discrete food entities;
- plant reproduction as an explicit organism lifecycle;
- richer long-term mountain / landscape engineering beyond the current dig/deposit relief;
- stronger visual distinction between natural relief, organism-built structures and water erosion.

## 5. Visual / microscope readability

Recent visual commits intentionally moved away from generic far-LOD diamonds at ordinary populations.

Key rules now:

- detailed pixel art is the normal mode;
- x4/x8 alone does not force coarse LOD at ordinary population;
- coarse far LOD is reserved for large population / real zoom-out conditions;
- heading still determines front/back orientation;
- organism sprites use atlas animation;
- current HEAD adds low-amplitude breathing/bobbing;
- species ID affects silhouette aspect ratio and small pixel markings;
- active feeding gets visible links / transfer cues;
- reproduction gets pulse FX;
- lysis gets visible fragment/burst cues;
- decomposer spores visibly contract/darken;
- dormant hyphae become thinner/duller while preserving lineage/species identity;
- terraforming particles already show active dig/deposit behavior.

The maintainer still considers the game visually under-polished. More animation / event readability / biome richness is wanted.

## 6. Performance architecture

Current path is intentionally incremental, preserving mechanics/biology.

Already implemented:

- adaptive biology / terrain cadence;
- deterministic cohorts;
- adaptive chemistry cadence;
- active HGT recipient queue;
- spatial phage scans;
- packed water-flow cache;
- cached species identity;
- cached derived motility phenotype;
- in-place bacterial population mutation with stable compaction only on death/division;
- adaptive frequency-metadata refresh;
- direct metabolic / motion-only cohort routing;
- dense motion hot-path optimizations;
- persistent `BacteriaHotStore`;
- **lazy** hot-store synchronization so rendering can consume packed state without mirroring every biological sub-tick;
- terrain bacteria evaluation cohorts from medium density upward;
- packed render snapshot for far bacterial rendering.

Do not reintroduce eager full hot-store synchronization every biological tick. That caused a large regression.

The next major structural performance milestone remains:

1. fuller packed SoA / chunked bacterial hot state;
2. GPU-resident chemistry / biome fields;
3. parallel / GPU agent kernels if still required.

Native C++ / GDExtension remains gated until algorithmic/data-layout/GPU work proves insufficient.

---

# Performance truth / target

At 60 biological ticks/s:

- x1 requires about 16.67 ms/tick;
- x2 about 8.33 ms/tick;
- x4 about 4.17 ms/tick;
- x8 about **2.08 ms/tick**.

Current system is nowhere near true x8 at dense population yet.

The renderer/scheduler now uses a hard ~15 ms main-thread simulation budget per rendered frame instead of allowing fast-forward to monopolize up to ~80 ms.

This improves visual responsiveness, but **does not make the biology actually x8**.

Always use `actual_sim_speed` (simulation time / wall time) as the truth.

Do not fake requested speed.

---

# Useful benchmark history

CI runner variance is significant. Do not judge a change from one runner result alone.

Important measured points from this branch history:

### Earlier reference around c2cfff6
- 500: ~16.48 ms/tick
- 2k: ~26.86 ms/tick
- 10k: ~22.61 ms/tick

### After adaptive tier / chemistry work
One strong run reached roughly:
- 500: 5.19 ms/tick
- 1k: 7.47
- 2k: 7.57
- 5k: 10.31
- 10k: 9.60

### After lazy hot-store correction
A repeat benchmark on `68ede53` showed approximately:
- 10k: **15.42 ms/tick**
- agents: **~9.02 ms**

This was much better than the eager hot-store implementation, where agents had regressed toward ~18.9 ms on one run.

Do not overreact to CI runner variance; compare repeated runs and subsystem timings.

---

# Last maintainer local telemetry before current HEAD

The latest local session published in issue #66 is:

- issue comment ID: **5995934156**
- build: **`2222688b09e9`**
- duration: 426 s (~7.1 min)
- Windows / NVIDIA / Forward+
- final bacteria: **1447**

Performance:
- frame max p50 / p95: **115.88 / 150 ms**
- sim step p50: **16.34 ms**
- core p50: **23.44 ms**
- terrain p50: **9.62 ms**
- FPS p50 / minimum: **18 / 6**
- achieved speed p50: **0.62x**

Ecology:
- bacteria final: **1447**
- protozoa final: **3**
- ciliates final: **1**
- flagellates final: **1**
- algae final: **12**
- decomposers final: **0**
- hyphae final: **3**
- predator reproduction: **0 proto / 0 ciliate / 0 flagellate**
- bacterial reproduction: **1595**
- predation events: **195 proto / 121 ciliate / 47 flagellate**

Evolution:
- phenotype species final / peak: **57 / 57**
- ecotypes final / peak: **1158 / 1158**
- generation: 20
- structural mutations: ~3252
- HGT: 10 / 11
- transformations: 0
- capability mixes: 29
- refugia recoveries: 6

Terraforming / biome:
- excavated: ~61
- deposited: ~21
- producer: **592**
- biofilm: **50**
- detrital: **0**
- fungal: **0**
- anoxic: **0**
- disturbed: 1
- recently modified: 4

The screenshot from this run exposed severe overview clutter from armor rectangles
and reproduction circles. The report also exposed a hard ciliate balance bug:
feeding capped energy at 16.0 while reproduction required 16.5.

This run directly motivated:
- `51e0a7d Rebalance living biome readability`

Therefore **do not treat 2222688 as the current target**. The next required
product-validation gate is a fresh local run on `51e0a7d` (or a newer
documentation-only HEAD above it).

---

# Recent commit chain to know

Newest first:

- `51e0a7d` — **Rebalance living biome readability**
  - removes enclosing armor/reproduction geometry;
  - density-aware overview batching with close-zoom detail recovery;
  - phenotype species drive stronger bacterial silhouettes;
  - fixes predator reproduction energy viability and earlier bacterial density pressure;
  - strengthens detrital/fungal recycling and decomposer persistence;
  - vegetation succession depends on living producer/exudate support;
  - derived marsh / sand-bar / crag habitats affect steering and substrate cost.

- `2222688` — **Polish living microscope presentation**
  - species silhouette/body-mark variation;
  - four phenotype bands;
  - stronger bounded anti-dominance / rare relief;
  - breathing/bobbing;
  - feeding/reproduction/lysis FX;
  - water sparkles;
  - seasonal palette;
  - richer tree/shrub/rock silhouettes.

- `92acd60` — **Keep fast-forward frames responsive**
  - hard main-thread simulation budget ~15 ms per rendered frame;
  - requested vs actual speed remains separate.

- `bc7d013` — **Make terraforming attribution readable**
  - localized disturbance;
  - dig/build traces;
  - lineage-colored attribution.

- `27b3ab4` — **Cut medium-density terrain evaluation cost**
  - terrain organism evaluation cohorting begins at medium density.

- `74376a4` — **Add seasonal living terrain cover**
  - grass → shrub → tree + rock.

- `f5629ce` — **Add seasonal terrain hydrology**
  - water depth / runoff / moisture / seasons.

- `c4e8670` — **Keep pixel art at ordinary populations**
  - x4/x8 no longer automatically forces ugly coarse glyphs.

Earlier important architecture:
- `68ede53` — lazy bacterial hot snapshots;
- `110eb9f` — persistent bacterial hot-state store;
- `606afb8` — dormancy telemetry;
- `3977663` — basal dormancy visually readable;
- `977a20e` — evolved decomposer / hyphal dormancy;
- `6798c94` — dense bacterial motion math;
- `09a067f` — adaptive population metadata;
- `2f57558` — population compaction only on identity changes.

---

# CI state at handoff

For code commit `51e0a7d`:

- parser/import checks: **SUCCESS**
- deterministic smoke test: **SUCCESS**
- push workflow run **37323204693** continued into the 10-minute ecology soak at
  the time this handoff note was refreshed.

Local visual validation is still required; CI cannot judge readability.

---

# Immediate next action for the next agent

Do this first, before adding more systems:

1. Ask the maintainer to pull and run code commit `51e0a7d` (or newer) if they have not already.
2. Have them test:
   - x1;
   - x4;
   - x8;
   - normal zoom and close zoom;
   - with `P` overlay briefly enabled.
3. Ask for one screenshot / video and let telemetry publish automatically to #66.
4. Analyze:
   - FPS;
   - `core`;
   - `terrain/earth`;
   - achieved vs requested speed;
   - visible species variation;
   - whether trees/shrubs/rocks are actually readable;
   - whether water motion is readable;
   - whether dig/build attribution is understandable;
   - whether `DISTURBED` still floods the map.
5. Then fix the largest measured problem instead of blindly adding another subsystem.

Do **not** start another large visual or ecology feature before seeing how `2222688` behaves locally unless the maintainer explicitly asks to skip validation.

---

# Known problems / likely next work

## Highest priority

### Performance
- 60 FPS at dense x1 is not guaranteed yet.
- true x8 is far from the 2.08 ms/tick biological target.
- continue #20 packed SoA/chunks;
- then GPU-resident fields (#57 / related GPU issues);
- do not sacrifice readable art to hide CPU cost.

### Species readability / coexistence
The previous local run had >1000 ecotypes but only 29 visible species at the end.

Code commit `51e0a7d` adds stronger species silhouettes and density-aware overview rendering, but this has **not yet been locally validated**.

Watch for:
- too many organisms still appearing identical;
- species count exploding into unreadable noise;
- rare-species relief becoming an artificial immortality mechanism.

### Terraforming clarity
Need to verify that:
- `DISTURBED` no longer occupies almost the whole map;
- dig and build traces are localized;
- lineage tint makes actor attribution understandable;
- old structures remain physically present while ecological state matures.

### Terrain richness
Current cover is still simplified.

Desired future directions:
- water erosion / sediment transport;
- river/stream channels and readable ponds;
- richer vegetation stages;
- explicit grazing / destruction of vegetation;
- clearer natural vs organism-built terrain;
- more readable mountains / mounds / tunnels / deposits;
- seasonal death/regrowth cycles that are visible at overview.

### Evolution event activity
The last local run reported:
- HGT = 0
- transformations = 0

This may simply be due to conditions / short duration, but should be checked. Evolution must not silently lose these mechanisms.

### Decomposers / hyphae
They now have dormancy/quiescence, but long-run guild persistence still needs telemetry validation.

---

# Godot shutdown warning note

The maintainer has seen messages such as:

- `Unreferenced static string`
- `RID allocations ... were leaked at exit`
- `PagedAllocator ... pages in use exist at exit`

when stopping the game with **Ctrl+C**.

Treat these first as forced-shutdown Godot cleanup artifacts, not proof of a runtime simulation fault.

Investigate only if they reproduce on a normal clean exit or correlate with an actual crash.

---

# Local PowerShell validation commands

Use this exact short sequence when the maintainer needs to test:

```powershell
cd E:\_Project\MicroC0re
git switch rebuild/pixel-microscope-v0.2
git pull --ff-only
git log -1 --oneline
& .\scripts\run_simulation.ps1
```

Expected latest **code** commit beneath any documentation-only handoff commit(s):

```text
51e0a7d Rebalance living biome readability
```

Use `git log -3 --oneline` rather than assuming the documentation commit itself is the code baseline.

Useful controls:

- `P` — performance / telemetry overlay
- `1` — x1
- `2` — x2
- `3` — x4
- `4` — x8

Telemetry should publish to issue #66 when enabled.

---

# GitHub connector-first rule

For GitHub bookkeeping, use GitHub connector tools directly.

Do not ask the maintainer to run PowerShell / `gh` merely to:
- create/update issues;
- update checklists;
- add PR comments;
- change labels;
- inspect CI;
- move workflow state when connector/project tools can do it.

Local PowerShell is for local Godot/RTX validation.

For multi-file code pushes on the active branch, preserve fast-forward safety:
- fetch current branch HEAD;
- build tree from its tree SHA;
- create commit with that exact parent;
- update ref without force.

If the branch moved, refetch and rebase/reapply; never overwrite newer work.

---

# Workflow / status protocol

Real workflow states:

- Backlog
- Todo
- In Progress
- Review
- Done

Issue titles must not encode workflow state.

If direct Project V2 mutation is unavailable, use exactly one of:

- `status:backlog`
- `status:todo`
- `status:in-progress`
- `status:review`
- `status:done`

The default-branch sync workflow maps these labels to the Project Status field.

Never claim a Project card moved unless the mutation/sync succeeded.

---

# End-of-turn discipline

After a substantial implementation pass:

1. push the branch;
2. confirm CI or explicitly state what remains untested;
3. update relevant issue / PR notes when useful;
4. update this handoff again when the global direction/state materially changes;
5. never describe untested local visual behavior as validated.

The next agent should be able to recover from GitHub alone.
