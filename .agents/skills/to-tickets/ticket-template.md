# {Ticket title}

> Which sections apply depends on the tracker. **local**: keep every section and prefix the H1 with the compound ID (`# {NNNN.NN}: {title}`). **github**: identity, status, and edges are issue metadata, so drop `## Status` and `## Blocked by` and keep the title clean. Mechanics: [`publish-local.md`](publish-local.md), [`publish-github.md`](publish-github.md).

## What to build

{The end-to-end behaviour this ticket makes work, from the user's perspective - not a layer-by-layer implementation list.}

## Status

{Local only - on github this is a label, not a body section. `ready-for-agent`, `ready-for-human`, or `done`. A fresh ticket is `ready-for-agent` when an agent can build and verify it end-to-end, or `ready-for-human` when it needs human judgment or a manual step first. The dispatch step flips it to `done` when its acceptance criteria are met.}

## Blocked by

{Local only - on github this is a native issue dependency, not a body section. The compound IDs of the tickets that gate this one (e.g. `0001.01`), or "None (can start immediately)".}

## Acceptance criteria

{Behavioural cases in Given / When / Then, the same grammar the spec's Testing & Seams section uses - external behaviour, not implementation detail. Each must be false at the commit the implementer starts from: the "Then" is the observation that would show it failing.}

- [ ] **{scenario}**
  - Given {starting state}.
  - When {action under test}.
  - Then {expected result}.
- [ ] **{scenario}**
  - Given {starting state}.
  - When {action under test}.
  - Then {expected result}.
