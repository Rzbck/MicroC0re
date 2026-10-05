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


## Stone-style construction checklist

When a page is created or materially rebuilt:

1. **Title first.** If the page cannot be named clearly, the design question is not clear enough yet.
2. **Date every page.** Printed/shared pages otherwise lose version context immediately.
3. **Choose the audience.** Engineering, art, systems design and the player-facing team do not need identical emphasis.
4. **Leave real white space.** Density is not completeness; cramming is a failure state.
5. **Use one central visual/focal point** when the problem benefits from it.
6. **Put the shortest explanatory statement under the focal visual.**
7. **Use callouts around the visual** for relationships and constraints.
8. **Callouts may themselves be small diagrams/illustrations**, with tiny clarifying notes.
9. **Use sidebars/checklists only for high-level goals, invariants or acceptance gates.**
10. **Make important things physically larger** — type, arrows, boxes or illustrations.
11. **Start small and enlarge only when the relationship genuinely needs it**: page → larger page → poster/one-wall. Do not solve confusion by shrinking fonts.
12. **Pick the visual form from the question**: flow chart, matrix, storyboard, timeline, spatial map, graph or hybrid spreadsheet.
13. **Show relationships, not just nouns.** Arrows, ordering, quantities, dependencies and feedback loops are the valuable part.
14. **Use the page to discover bad design early.** If a proposed system becomes an unreadable knot, simplify/cut before implementation cost grows.
15. **Replace obsolete pages actively.** Do not rely on the team/agent to discover the newest version somewhere else.
16. **Let quantitative tools feed the page.** A spreadsheet/benchmark can be the source, while the one-page remains the digestible decision surface.

## Failure modes

A page fails when:
- it is a wiki article squeezed into one screen;
- every element has equal visual weight;
- it needs a meeting to explain what the arrows mean;
- it has no date/version context;
- it shows components but hides their relationships;
- it contains detailed implementation that belongs in deep docs;
- it is technically complete but nobody wants to look at it.

## MicroC0re adaptation

MicroC0re is simulation-heavy, so every active page should connect three layers whenever relevant:

**player-visible phenomenon → simulation mechanism → measurable evidence**

Example:

`species visibly diverge` → `stable phenotype clusters + mutation/HGT + selection` → `species-per-guild timeline, generation, predation/reproduction metrics`.

That prevents documents from becoming either pure art direction or pure implementation notes.
