# MicroC0re — AI handoff

This file is deliberately kept on the default branch so a fresh ChatGPT/Codex/agent session can recover the live project without asking the maintainer to reconstruct context.

## Live project identity

- Repository: `Rzbck/MicroC0re`
- GitHub Project: `MicroC0re` (#2)
- Project V2 node: `PVT_kwHOAKdXDM4BldFb`
- Active development branch: `rebuild/pixel-microscope-v0.2`
- Active development PR: #19
- Current product gate: #14

The GitHub Project **Status field is canonical**.

## Mandatory fresh-session bootstrap

1. Read `/AGENTS.md`.
2. Inspect Project `MicroC0re` (#2) when Project V2 access exists.
3. Inspect PR #19 and the relevant Issues.
4. Read the active branch versions of:
   - `AGENTS.md`
   - `docs/CURRENT_DIRECTION.md`
   - `docs/STATUS.md`
   - the relevant domain docs.
5. Continue blocking `In Progress` / `Review` work before starting unrelated `Todo` work.

Do not ask the maintainer to repeat information already recorded in GitHub.

## Connector-first GitHub rule

Use GitHub-native connector/agent tools for repository bookkeeping.

Do not ask the maintainer to run PowerShell, `gh`, or Git merely to:
- create/update Issues;
- update acceptance checklists;
- change labels;
- comment/update PRs;
- close/reopen work;
- move Project cards when Project V2 mutation is exposed.

Local commands are reserved for local Godot/RTX validation that cannot be executed remotely.

## Project status protocol

Real states:
- Backlog
- Todo
- In Progress
- Review
- Done

Do not encode those states in Issue titles.

If Project V2 write is exposed, update the card directly.

If it is not exposed, use exactly one connector-writable status label:
- `status:backlog`
- `status:todo`
- `status:in-progress`
- `status:review`
- `status:done`

The default-branch workflow `.github/workflows/project-board-sync.yml` translates those labels to the Project Status field when repository secret `MICROCORE_PROJECT_TOKEN` is configured.

## End-of-turn handoff contract

After meaningful work:
1. update the active branch;
2. update relevant Issues/checklists;
3. update Issue/PR status;
4. add a concise PR #19 handoff comment when implementation changed;
5. update `docs/STATUS.md` on the active branch when overall state changed;
6. state local validation requirements accurately.

The next agent should be able to continue from GitHub alone.
