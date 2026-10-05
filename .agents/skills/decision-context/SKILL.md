---
name: decision-context
description: Build the project's shared language and record decisions worth remembering. Use when clarifying domain terminology, writing or editing CONTEXT.md, or when a hard-to-reverse decision is made that a future reader would question.
---

# Decision Context

Shape the project's shared language as you design, and record the decisions that a future reader would otherwise have to reverse-engineer. This is the active discipline - challenging loose terms and writing things down the moment they settle - not merely reading the docs for vocabulary, which any skill can do.

Two artifacts, both under `docs/`, both created lazily - only once there is something real to write:

```
docs/
├── CONTEXT.md          ← the glossary
└── adr/                ← one file per decision: 0001-slug.md
```

If no `docs/CONTEXT.md` exists, create it when the first term is nailed down. If no `docs/adr/` exists, create it when the first decision clears the bar below.

## Shaping the glossary (docs/CONTEXT.md)

`docs/CONTEXT.md` is a glossary and nothing else - the canonical name for each concept the project talks about. Keep implementation detail out of it entirely; it is not a spec, a design note, or a scratchpad. Only terms specific to this project belong. General programming concepts (timeouts, retries, error types) do not, however heavily they're used.

As you work, keep the language honest:

- **Challenge conflicts.** If a term is used in a way that clashes with its definition, say so at once: "The glossary defines 'cancellation' as X, but you seem to mean Y - which is it?"
- **Sharpen fuzz.** When a word is vague or overloaded, propose a single precise name: "You said 'account' - do you mean the Customer or the User? Those are different things."
- **Test with scenarios.** When concepts relate in a way that's still fuzzy, invent a concrete edge case that forces the boundary to be made precise.
- **Check against the code.** If a claim about how something works contradicts the code, surface it rather than papering over it.
- **Write it down inline.** The moment a term settles, add or update it in `docs/CONTEXT.md`. Don't batch these up.

Record terms using the scaffold in [`context-template.md`](context-template.md). Be opinionated: when several words exist for one concept, pick the best and list the rest under `_Avoid_`, omitting the line entirely when there is nothing to avoid. Keep each definition to a sentence or two, saying what the term *is*, not what it does. Group terms under subheadings only if natural clusters emerge; a flat list is fine otherwise.

## Recording decisions (ADRs)

An ADR records *that* a decision was made and *why* - not how it was built. Do not write one for every choice. Offer an ADR only when the user explicitly asks for one, or when all three of these hold:

1. **Hard to reverse** - changing your mind later carries a real cost.
2. **Surprising without context** - a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **A genuine trade-off** - there were real alternatives and you picked one for specific reasons.

If any one is missing, skip it. An easy-to-reverse decision you'll just reverse; an unsurprising one nobody questions; a decision with no alternative records nothing beyond "we did the obvious thing." Typical qualifiers: architectural shape, technology choices that carry lock-in, boundaries and explicit non-goals, and deliberate deviations from the obvious path.

Use the scaffold in [`adr-template.md`](adr-template.md): Title, Status, Context, Decision, Consequences. Write every section terse - a sentence or two of plain, concrete language, no preamble or restatement. The value is recording *that* a decision was made and *why*, not filling out sections at length. In the Context section, lay out the alternatives as an explicit list - "Option 1", "Option 2", and so on - rather than as running paragraphs, so a reader can see at a glance what was weighed. Then have the Decision reference the chosen option by its number ("We will go with Option 2: ...").

**An ADR is immutable once written.** The only part of an existing ADR that may ever change is its Status line - to `Deprecated` when the decision no longer applies, to `Superseded by ADR-NNNN` when a newer ADR replaces it, or from `Proposed` to `Accepted`. Title, Context, Decision, and Consequences are never edited after the fact: not to match how the code turned out, not to add detail learned during the build, not to fix the wording. If an ADR is wrong, outdated, or incomplete, that is a new decision - write a new ADR and point the old one's status at it. If the code has drifted from an accepted ADR, the code is what is wrong until a new ADR says otherwise.

Files live in `docs/adr/` as `NNNN-slug.md`. Number sequentially with 4-digit zero-padding: scan the directory for the highest existing number and add one, starting at `0001` if it is empty.
