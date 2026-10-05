# GitHub Project automation

MicroC0re uses GitHub Project **MicroC0re #2** as the canonical workflow board.

## Goal

A coding agent should be able to:
1. read the repository handoff;
2. update an Issue/PR through the GitHub connector;
3. change one `status:*` label;
4. let GitHub Actions add/update the corresponding Project card automatically.

No maintainer PowerShell should be required for routine GitHub bookkeeping.

## Status labels

Exactly one workflow label should represent the intended Project status:

| Label | Project Status |
| --- | --- |
| `status:backlog` | Backlog |
| `status:todo` | Todo |
| `status:in-progress` | In Progress |
| `status:review` | Review |
| `status:done` | Done |

The labels are repository metadata, so ChatGPT/Codex GitHub tools that can edit Issues/PRs can update them even when the current product surface does not expose Project V2 fields directly.

## Automation workflow

The default branch contains:

`.github/workflows/project-board-sync.yml`

It:
- creates the five status labels if missing;
- normalizes an Issue/PR to one status label;
- resolves Project #2 and its Status option IDs dynamically;
- adds the Issue/PR to the Project if needed;
- writes the real Project Status field;
- maps closed/merged work to Done.

## One-time credential

GitHub Actions cannot inherit the maintainer's local `gh auth` session or ChatGPT connection.

The repository therefore needs one Actions secret:

`MICROCORE_PROJECT_TOKEN`

Use a GitHub token authorized to mutate the user's Project V2 and access this private repository. GitHub's official Projects automation documentation uses a personal access token with `project` and `repo` scopes for this pattern.

Do **not** commit or paste the token into repository files, Issues, PRs, or chat.

Once the secret exists, future status changes are connector-only.

## Agent protocol

At work start:
- set the Issue to `status:in-progress`.

When implementation is awaiting maintainer/local validation:
- set `status:review`.

When accepted:
- set `status:done` and close the Issue if appropriate.

When explicitly deferred:
- set `status:backlog`.

For newly created work:
- use `status:todo` unless work begins immediately.

If the current agent has direct Project V2 write capability, it may update the Project field directly instead. Keep the status label consistent so lower-capability sessions still understand the state.

## Handoff

Codex automatically consumes repository `AGENTS.md` instructions according to its documented instruction hierarchy. Other ChatGPT GitHub experiences retrieve repository content on demand, so `README.md`, `AGENTS.md`, and `docs/HANDOFF.md` all point to the same workflow contract.

The project must remain understandable from GitHub alone.


## One-page design protocol

MicroC0re uses `docs/one-pages/` as the active visual design layer.

For every substantial design/code tranche, an agent must:
1. identify the one-page whose design question is being changed;
2. update its date, current rule, measurable success criteria and latest evidence;
3. create a new one-page instead of expanding an existing page when the work introduces a new design question;
4. keep implementation details in the existing deep docs; the one-page records relationships, constraints and decisions;
5. use telemetry/soak/benchmark evidence to update the page instead of relying on subjective claims alone.

A one-page is not a backlog dump. If it cannot be understood at a glance, split it.

Current active pages:
- `00_GAME.md` — overall experience and living-world loop;
- `01_EVOLUTION_SPECIES.md` — endless evolution, species and refugia;
- `02_BIOME_SUCCESSION.md` — ecological succession and terraformation feedback;
- `03_SCALE_PERFORMANCE.md` — scaling without deleting biology;
- `04_MICROSCOPE_READABILITY.md` — observation, movement and visual continuity.
