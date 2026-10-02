# MicroC0re — AI handoff

This document exists so a fresh ChatGPT/Codex/agent session can continue the project without asking the maintainer to reconstruct context.

## Repository / project identity

- Repository: `Rzbck/MicroC0re`
- GitHub Project: `MicroC0re` (#2)
- Project V2 node: `PVT_kwHOAKdXDM4BldFb`
- Current development branch: `rebuild/pixel-microscope-v0.2`
- Current active PR: #19
- Current visual product gate: #14
- Active living-biome epic: #38

The GitHub Project **Status field is the canonical workflow state**.

## Mandatory session bootstrap

A fresh agent must do this before choosing work:

1. Read `/AGENTS.md`.
2. Read `docs/CURRENT_DIRECTION.md`.
3. Read `docs/STATUS.md`.
4. Inspect active PR #19 and its recent conversation/commits.
5. Inspect the relevant GitHub Project cards / Issues before starting work.
6. Read the issue body and acceptance criteria for the work being changed.
7. For evolution work, also read `docs/EVOLUTION.md` and `docs/RESEARCH.md`.
8. For performance/GPU work, also read `docs/OPTIMIZATION_STRATEGY.md`.

Do not ask the maintainer to repeat project history that is already in GitHub.

## Connector-first rule

For GitHub bookkeeping, **use the GitHub connector / GitHub-capable agent tools directly**.

Do not ask the maintainer to run PowerShell, `gh`, Git commands, or manually move Project cards merely to:
- create/update Issues;
- update checklists;
- comment on PRs;
- change labels;
- close/reopen Issues;
- change Project status when Project V2 write capability is available.

Local PowerShell is reserved for things the agent cannot execute remotely, especially running the maintainer's local Godot/RTX tests.

## Project status protocol

Real workflow states:

- `Backlog`
- `Todo`
- `In Progress`
- `Review`
- `Done`

Issue titles must **not** encode workflow state. Bracketed title tags are domain tags only, for example `[GPU]`, `[Evolution]`, `[Kernel]`.

### Preferred path

If the current GitHub connector exposes Project V2 mutation:
1. move the card directly;
2. update the Issue/PR;
3. update `docs/STATUS.md` only when the summarized state materially changed.

### Compatibility path

Some ChatGPT/GitHub surfaces expose Issues/PRs/labels but not Project V2 fields.

In that case use exactly one connector-writable workflow label:

- `status:backlog`
- `status:todo`
- `status:in-progress`
- `status:review`
- `status:done`

The default-branch workflow `.github/workflows/project-board-sync.yml` maps these labels to the real GitHub Project Status field.

Never claim the card moved unless either:
- the Project mutation succeeded directly; or
- the Project sync workflow succeeded.

## Status transition rules

When beginning implementation on an Issue:
- set/move it to `In Progress`;
- add a short Issue comment only when useful;
- link the active PR.

When implementation is complete but maintainer/local validation is still needed:
- set/move it to `Review`;
- record exactly what remains to validate.

When validation and acceptance criteria pass:
- set/move it to `Done`;
- close the Issue if appropriate.

When a task is explicitly deferred/gated:
- use `Backlog`.

Do not start random `Todo` work while a blocking `In Progress` item should be finished first.

## End-of-turn handoff

After a substantial code/research pass, the agent must leave GitHub self-explanatory:

1. push/update the working branch;
2. update relevant Issue checklists/bodies;
3. update the Issue/PR workflow status;
4. comment on PR #19 with what changed, what was measured, and what still needs local validation;
5. update `docs/STATUS.md` if the overall project state changed;
6. do not mark untested code as passing.

The next agent should be able to recover state from GitHub alone.

## Current maintainer preferences that affect product decisions

- The microscope view is artwork first, not a debug dashboard.
- No permanent top-left profiler/HUD.
- Escape opens a clean menu.
- Clicking an organism opens a left-side inspector.
- Overview is cover-fit; zoom-out must never shrink the living world into a tiny island.
- Pixel art must be deliberate, not vector art with nearest filtering.
- Evolution should be observable: mutation, lineage divergence, HGT, ecology and later richer eco-evolution.
- Desktop scaling is GPU-first where the workload is parallel.
- Performance claims require measurements.

See `docs/CURRENT_DIRECTION.md` for the complete contract.
