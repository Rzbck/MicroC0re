# Session telemetry

MicroC0re can record a small bounded performance report for each visible game
session. This is intended to make long-run stutter and interaction failures
reproducible without copying console logs by hand.

## Privacy model

The repository is public. Public reports are therefore **opt-in** and built from
an explicit allowlist.

Published fields:
- random per-session identifier;
- public build SHA and simulation seed;
- Godot version;
- OS family only;
- GPU vendor only (not exact adapter model);
- rendering backend;
- coarse display bucket;
- 2-second bounded samples of FPS, frame/process time, simulation-step time,
  draw time, population counts, visible terrain tiles, terrain revision, moved
  soil, capability fragments, zoom and quarter-turn camera state;
- aggregate input counters for rotation, zoom, selection and menu use.

Never published:
- username/account name;
- hostname;
- IP or MAC address;
- file paths;
- environment variables;
- locale or location;
- exact GPU model/driver;
- raw console output, exception text or arbitrary strings;
- any stable machine fingerprint.

Local reports live under `.microcore/`, which is gitignored.

## Enable automatic GitHub publication

Run once from PowerShell:

```powershell
.\scripts\enable_session_telemetry.ps1
```

Future `run_simulation.ps1` sessions are posted as comments to issue #66 after
the game exits, using an already-authenticated GitHub CLI. No GitHub token is
stored by MicroC0re.

Disable at any time:

```powershell
.\scripts\disable_session_telemetry.ps1
```

If GitHub CLI is missing, unauthenticated, or publication fails, the sanitized
report simply remains local for inspection/retry.
