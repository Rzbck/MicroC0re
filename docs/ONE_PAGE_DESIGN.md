# MicroC0re One-Page Design System

**Date:** 2026-10-05  
**Audience:** design, simulation, rendering, performance, future coding agents  
**Purpose:** make every important game-design relationship understandable at a glance.

## The rule

One page answers **one design question**. It is not a compressed wiki page.

Every active page contains:
- a precise design question;
- the player-facing promise;
- one dominant diagram or matrix;
- constraints / invariants;
- measurable success criteria;
- latest evidence from telemetry, soak, benchmark or live review;
- the current decision and the next uncertainty.

Use deep documents such as `BIOLOGY.md`, `BIOME.md`, `EVOLUTION.md` and `OPTIMIZATION_STRATEGY.md` for implementation detail.

## Visual grammar

Prefer, in this order:
1. **flow diagram** for loops and causality;
2. **matrix** for interactions/trade-offs;
3. **timeline** for progression/succession;
4. **map** for spatial relationships;
5. **storyboard** for player-visible sequences.

Keep white space. Use short callouts. Put numbers beside the relationship they constrain instead of hiding them in prose.

## Update protocol

At the start of a tranche, choose the relevant one-page. At the end:
- update the date;
- update changed arrows/rules;
- record the validating metric;
- mark unresolved contradictions;
- split the page if a second independent design question appears.

The page is a **design contract**, not a history log. Git already stores history.

## Source method

Adapted from Stone Librande's GDC **One-Page Designs** (2010), **Simulating a City, One Page at a Time** (2013), and his current CMU game-design coursework. The useful principles for MicroC0re are: one core idea per page, a strong central visual, concise callouts, explicit audience, date/version, whitespace, relationship-first layout, and active replacement/distribution of outdated pages.

References:
- https://gdcvault.com/play/1012356/One-Page
- https://www.gdcvault.com/play/1018764/Simulating-a-City-One-Page
- https://stonetronix.com/gamedesign/
