# AGENTS.md — MicroC0re bootstrap

This default-branch file exists primarily as a durable handoff entry point for AI/coding agents.

## Mandatory first action

Read `docs/HANDOFF.md` before choosing work.

The live implementation is currently on branch `rebuild/pixel-microscope-v0.2` / PR #19, not on this minimal default branch. Inspect that PR and read the active branch's own `AGENTS.md`, `docs/CURRENT_DIRECTION.md`, and `docs/STATUS.md` before changing project code.

## GitHub workflow

- GitHub Project `MicroC0re` (#2) Status is the canonical workflow state.
- Use GitHub connector/agent tools for Issues, PRs, labels and Project cards.
- Never encode workflow state in Issue titles.
- Do not ask the maintainer to run PowerShell just for GitHub bookkeeping.
- If Project V2 mutation is unavailable, use one `status:*` label; `.github/workflows/project-board-sync.yml` is the compatibility bridge.
- Never claim a Project card was updated unless direct Project mutation or the sync workflow succeeded.

## Local validation

The maintainer's local Godot/RTX tests are the legitimate reason to hand off a PowerShell test block. GitHub bookkeeping is not.
