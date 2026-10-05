---
name: to-tickets
description: Break a spec into tracer-bullet tickets - narrow vertical slices, each declaring what blocks it - and publish them to the configured tracker. Use once a spec exists; every spec becomes at least one ticket, since agents and humans build only from tickets.
disable-model-invocation: true
---

# To Tickets

Break a spec into **tickets**: tracer-bullet vertical slices, each declaring the tickets that **block** it. The result is a task graph a fleet of fresh sessions can work in parallel, not a checklist for one session to grind through.

By the time this runs, [[to-spec]] has settled what gets built and why. Do not reopen decisions - slice what is already agreed. The tickets decide nothing new; they cut the settled plan into pieces small enough to build.

Every spec becomes at least one ticket. Agents and humans build only from tickets, never straight from a spec - so a spec that is never sliced is a spec that never gets built. If the whole change fits in one fresh context window, cut a single ticket that carries the whole spec: one frontier ticket, no blockers, `ready-for-agent` unless the spec's own call is otherwise. Don't manufacture edges to split it further - one honest unit of work is one ticket, and that is a valid breakdown, not a failure to break down.

## How it works

1. **Resolve the tracker.** Read `.tracker.toml` at the project root to learn where tickets go - it names `local` or `github`, the same destination [[to-spec]] published the spec to. See [[tracker-config]] for the file's shape; if it is missing or malformed, hand off to [[tracker-config]] rather than guessing a destination.

2. **Read the spec.** Take the spec passed as an argument (a `docs/specs/NNNN-slug/` folder or a GitHub issue), or the one just written in this session. Read its full body, including the agreed seams and the out-of-scope section - a ticket that builds something the spec refused is a defect.

3. **Explore the repo.** Ground the tickets in how the code actually works, and speak in the project's vocabulary - use the terms from `docs/CONTEXT.md` and respect the ADRs in the area you're touching (see [[decision-context]]). Delegate the digging to a subagent. Look for **prefactoring** that makes the later work easy - "make the change easy, then make the easy change" - and order it first.

4. **Draft vertical slices.**

   <vertical-slice-rules>

   - Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer.
   - A completed slice is demoable or verifiable on its own - if you cannot answer "what can I demo when this is done?" with a behaviour, it is a horizontal slice; redraw it.
   - Each slice is sized to fit in a single fresh context window.
   - Prefactoring comes first, before the feature slices that rely on it.

   </vertical-slice-rules>

   Give each ticket its **blocking edges**: the other tickets that must finish before it can start. A ticket with no blockers is on the **frontier** and can be grabbed immediately.

   Classify each ticket by who should build it once it reaches the frontier: **ready-for-agent** when an agent can build and verify it end-to-end from the spec, or **ready-for-human** when it turns on a call the spec left open, a manual or external step an agent cannot perform, or a change too risky to hand off unattended. Default to ready-for-agent; reach for ready-for-human only with a reason.

   **Wide refactors are the exception.** A wide refactor is one mechanical change (rename a shared column, retype a shared symbol) whose blast radius breaks call sites across the whole codebase at once, so no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand → migrate → contract**. Expand: add the new form beside the old so nothing breaks. Migrate: move call sites over in batches sized by blast radius, one ticket per batch, each blocked by the expand - the build stays green because the old form still exists. Contract: delete the old form once no caller remains, blocked by every migrate batch.

5. **Quiz the user.** Present the breakdown as a numbered list before publishing anything. For each ticket show its title, what it delivers (the end-to-end behaviour), what blocks it, and whether it is ready-for-agent or ready-for-human. Then ask:

   - Does the granularity feel right - too coarse, too fine?
   - Are the blocking edges real - does each ticket depend only on tickets that genuinely gate it?
   - Is the agent/human split right - is anything marked ready-for-agent that actually needs a human, or held back that an agent could take?
   - Should any tickets merge or split?

   Iterate until the user approves. Nothing reaches the tracker before then.

6. **Publish** the approved tickets. These rules hold whatever the tracker:

   - Publish in dependency order - blockers first. On github this is required: a blocker's issue number must exist before a later ticket can reference it. On local the IDs are yours to assign up front, so ordering is for readability, not correctness.
   - One ticket per file or issue, never combined, using the scaffold in [`ticket-template.md`](ticket-template.md).
   - Every ticket carries an **identity** that links it to its parent spec, the **status** (`ready-for-agent` or `ready-for-human`) settled in the quiz, and its **blocking edges**.
   - A ticket is on the **frontier** when its status is not `done` and every ticket it is blocked by is `done`.
   - This skill never marks a ticket `done` - that is the dispatch step's job - and never modifies the parent spec.
   - Ticket bodies avoid file paths and code snippets; they go stale fast. The exception is a snippet that pins a decision more precisely than prose can (a schema, a type shape, a state machine); inline just the decision-rich part.
   - Ticket bodies say what to verify, not which tool verifies it. Ask for visual checks through [[before-after]], never by naming Puppeteer, Playwright or another browser tool - the skill picks a tool that runs where the ticket is built.
   - NEVER add agent attribution, a generated-by credit, or a session link to a ticket's title or body.

   How a ticket's identity, status, and edges are physically recorded is tracker-specific. Follow the mechanics for the configured tracker: [`publish-local.md`](publish-local.md) for `local`, [`publish-github.md`](publish-github.md) for `github`.

## Completion

The tickets are done when every one answers "what can I demo when this is done?" with a behaviour, the frontier ticket has no blockers and can start immediately, and the edges between them are real. Stop there. This skill produces the task graph; it does not build it. Dispatch is a separate step the user runs - one ticket per fresh session, working the frontier.
