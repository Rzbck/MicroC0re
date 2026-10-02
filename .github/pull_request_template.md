## What changed

Describe the behavior or model changed by this PR.

## Linked issue

Closes #

## Model / evidence

- [ ] No biology/math behavior changed.
- [ ] Biology/math changed and docs were updated.
- [ ] New research references were added to `docs/RESEARCH.md`.

## Validation

- [ ] Headless smoke test passed.
- [ ] Determinism checked.
- [ ] No NaN/Inf or negative concentrations.
- [ ] Renderer remains independent from simulation state.
- [ ] I am explicitly stating below if tests could not be run.

Command:

```powershell
./scripts/run_headless.ps1
```

## Notes / limitations

Document uncalibrated parameters, shortcuts, and follow-up work.


## Visual / performance gate

For renderer/art/camera work:
- [ ] I read `docs/CURRENT_DIRECTION.md`.
- [ ] No Godot default grey/clear area is visible at supported zoom.
- [ ] Pixel-art work follows `docs/ART_DIRECTION.md` rather than relying on nearest filtering alone.
- [ ] Off-screen culling / LOD behavior was considered.
- [ ] Before/after FPS or timing numbers are included below for performance-sensitive changes.
- [ ] The agreed baseline does not fall below 60 FPS without an explicit documented exception.
- [ ] Important interactions are staged/readable rather than collision -> delete.

### Performance measurements

Scene / population / zoom:
Before:
After:
Bottleneck notes:
