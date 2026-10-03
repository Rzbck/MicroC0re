# Mathematical model

## Units

v0.1 treats world distance as approximately micrometre-scale, but chemical concentration and several energetic coefficients are normalized.

Do not interpret v0.1 output quantitatively until parameters are calibrated.

## 1. Scalar diffusion

For a scalar concentration field `c(x,y,t)`:

```text
∂c/∂t = D ∇²c + S - U - λc
```

where:
- `D` is diffusion coefficient;
- `S` is local source;
- `U` is uptake/sink;
- `λ` is first-order decay.

The CPU reference solver uses a 5-point finite-difference Laplacian.

For equal grid spacing `h`:

```text
∇²c ≈ (cL + cR + cU + cD - 4c) / h²
```

For explicit Euler diffusion in 2D, the implementation substeps so the diffusion term remains inside the standard stability region, approximately:

```text
D Δt / h² <= 1/4
```

v0.1 uses clamped neighbor lookup, equivalent to a simple no-flux-style boundary approximation.

## 2. Nutrient uptake

A Monod-like saturation curve is used:

```text
u(c) = umax * c / (K + c)
```

Actual uptake is capped by the amount of nutrient physically available in the sampled field cell.

## 3. Energy budget

A minimal internal energy balance:

```text
dE/dt = Y * uptake - Pmaintenance - Pmove
```

where `Y` is a normalized energetic yield.

Growth receives only energy above a reserve threshold.

## 4. Run-and-tumble chemotaxis

Each cell maintains a low-pass estimate `m` of recent concentration:

```text
dm/dt = (c - m) / τ
```

The difference `c - m` indicates whether the recent trajectory is improving conditions.

The tumble hazard is biased exponentially:

```text
λtumble = λ0 * exp(-χ * clamp(c - m))
```

A tumble during timestep `dt` is sampled from:

```text
P(tumble) = 1 - exp(-λtumble * dt)
```

This creates statistical gradient climbing without giving the agent a target vector.

## 5. Rod geometry

A bacterium is a 2D spherocylinder.

The straight centerline segment has half-length:

```text
s = max(0, (L - 2r)/2)
```

and endpoints:

```text
p0 = x - a*s
p1 = x + a*s
```

where `a` is the unit orientation vector.

For two rods, closest points between centerline segments are found analytically. If their separation `d` is less than `r1+r2`, overlap is resolved along the contact normal, with a small rotational response from the contact lever arm.

This is a qualitative soft-contact solver in v0.1, not yet a calibrated Hertzian/contact-force model.

## 6. Binary fission

Fission is state-triggered:

```text
L >= Ldivision
and
E >= Edivision
```

The parent becomes two daughter states with split energy and small opposite offsets along the parent axis.

## 7. Gray-Scott research module

The planned reaction-diffusion laboratory uses:

```text
∂u/∂t = Du∇²u - uv² + f(1-u)
∂v/∂t = Dv∇²v + uv² - (f+k)v
```

This is a pattern-forming chemical system. It must remain conceptually separate from claims about living bacterial agents.

## 8. Producer self-shading

The deterministic spatial/day-night model provides an ambient light value `L0` in the range `[0, 1]`.

For local producer biomass `B` (clamped to `[0, 1]`), the CPU reference uses a cheap qualitative attenuation:

```text
T(B) = 1 / (1 + kshade * B)
Leffective = clamp(L0 * T(B), 0.025, 1)
```

with the current qualitative coefficient:

```text
kshade = 0.90
```

This creates negative density feedback: dense producer mats receive less effective light, which reduces local photosynthetic growth/energy gain and oxygen production. The rational form is deliberately inexpensive and maps cleanly to the planned GPU field pipeline.

This is **not** a calibrated Beer-Lambert optical model and is not claimed to reproduce a specific algal species, pigment spectrum, water depth, or turbidity profile.

## Determinism

For reproducible runs:
- fixed `dt`;
- fixed seed;
- stable iteration order;
- no frame-delta-dependent biology;
- no rendering-driven RNG;
- deterministic neighbor ordering after future spatial indexing.
