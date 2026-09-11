# Fragment Poster V18 Memory Wall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the approved V18 asymmetric memory-wall fragment poster as a standalone HTML visual mockup.

**Architecture:** One self-contained HTML file defines the brand layer, left-aligned title layer, five-slot asymmetric photo wall, and lightweight progress layer with embedded CSS. The mockup uses deterministic remote placeholder photos so the layout can be reviewed without Flutter or backend dependencies.

**Tech Stack:** HTML5, CSS Grid, CSS Flexbox, Google Fonts.

## Global Constraints

- Keep the poster at `3:4` portrait ratio.
- Use the warm-white and gold palette from the approved spec.
- Show five asymmetric slots with three filled and two pending at middle-right and lower-right.
- Do not modify Flutter, backend, admin, or shared production code.
- Deliver only `docs/design/海报设计/碎片海报设计/fragment_poster_v18_memory_wall.html`.

---

### Task 1: Create And Visually Verify V18 HTML

**Files:**

- Create: `docs/design/海报设计/碎片海报设计/fragment_poster_v18_memory_wall.html`

**Interfaces:**

- Consumes: `docs/superpowers/specs/2026-09-11-fragment-poster-v18-memory-wall-design.md`.
- Produces: A browser-openable V18 visual mockup named `fragment_poster_v18_memory_wall.html`.

- [ ] **Step 1: Create the standalone mockup**

Create the HTML with a `360px`-bounded `3:4` poster. The top uses left-aligned LUMIRA branding and a light `拼碎片` capsule. The title uses Noto Serif SC and an `em` accent. The photo wall uses CSS Grid with columns `1.24fr 1fr`, three rows, and `7px` gap. The tall upper-left photo spans rows 1–2; the upper right holds a filled photo, the middle right is pending, the lower left holds a filled wide photo, and the lower right is pending. The progress row has a large `3 / 5`, five segments with three filled, and `还差 2 帧 · 一起凑齐这束光`.

- [ ] **Step 2: Open and inspect the mockup**

Run:

```powershell
Start-Process "docs/design/海报设计/碎片海报设计/fragment_poster_v18_memory_wall.html"
```

Expected: One V18 poster is displayed, with one tall photo upper-left, an upper-right filled photo, the middle-right pending slot, one wide photo lower-left, and the lower-right pending slot.

- [ ] **Step 3: Check acceptance criteria**

Verify each item visually:

1. Three photo slots show placeholder photos; the middle-right and lower-right slots show `+ 待拼`.
2. No diagonal crack, circular certificate frame, or equal-grid template appears.
3. Progress reads `3 / 5`, with three of five gold segments filled.
4. No text overflows or clips outside the poster.

- [ ] **Step 4: Commit the mockup**

Run:

```powershell
git add docs/design/海报设计/碎片海报设计/fragment_poster_v18_memory_wall.html
git commit -m "docs(design): add fragment poster v18 memory wall mockup"
```

Expected: A commit containing only the V18 HTML mockup is created.
