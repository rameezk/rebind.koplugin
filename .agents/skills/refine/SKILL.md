---
name: refine
description: Refine a piece of work - a new feature, a refactor, a bug fix - through questioning until a shared understanding is reached and the plan is ready to build.
disable-model-invocation: true
---

# Refine

Question the user hard, and keep going until both of you actually agree on what gets built. Hold off on any implementation until that agreement is explicit.

## How it works

Treat the plan as a **design tree**: each choice opens up the smaller choices that sit beneath it. Walk down every branch so nothing important is left to assumption.

Move through the tree in **rounds**, guided by the **frontier** - the set of choices whose inputs are already decided, so you can raise them now without second-guessing answers you don't have yet. Put the entire frontier to the user in a single round, then hold for their replies before continuing. If a question hinges on another that's still unanswered this round, save it for a later one.

Every set of answers redraws the tree: resolved choices extend the frontier and open up whatever was waiting on them. Rebuild the frontier from there and run the next round.

## Round format

Number the questions and lead each with the answer you'd pick, so the user can sign off with a single word.

```
❓ **Q1** - **<question title>**: <question body, may run several paragraphs, including options>

💡 <the answer you'd pick>

---

❓ **Q2** - **<question title>**: <question body>

💡 <the answer you'd pick>
```

## Finding facts

Digging up facts is on you, not the user. When a question turns on something in the environment - a file, a config value, an installed dependency, how some code behaves - send a subagent to find out rather than asking the user for what you could check yourself.

Don't stall the round waiting on it. An in-flight lookup is just another unresolved input, so only the questions that depend on its result wait; raise the rest of the frontier right away.

## Recording decisions

Refining is where decisions get made, so it is also where they get recorded - inline, the moment they settle, not deferred to some later step. When a choice settles that a future reader would otherwise have to reverse-engineer, or a term needs pinning down, hand off to [[decision-context]] right then: an ADR if the decision clears its bar (hard to reverse, surprising without context, a genuine trade-off), a `docs/CONTEXT.md` entry if a term just got sharpened. Don't batch these up to the end, and don't leave them for [[to-spec]] to maybe catch - the spec references the record, it doesn't create it.

## No question left unanswered

Refine is the one place questions get answered, so no question may leave it open. An answer the user has not explicitly agreed to is not an answer: the recommended pick is a proposal until they sign off, and a gap you quietly filled to keep moving is an assumption, not a decision. Every branch either settles on the user's word or stays on the frontier - it never gets written down as though it were resolved.

This holds past the end of the session too. When a later step surfaces a question that was never actually decided - a seam that cannot be placed, a slice that cannot be sized, a fork that only shows up mid-build - that question belongs back here, not in the spec or the ticket.

## Completion

The calls belong to the user: surface each one and wait for it. You're finished when the frontier runs dry - every branch of the tree walked, nothing quietly assumed and nothing left open behind a pick the user never confirmed.

Refining is not building. When the frontier runs dry, stop. Summarize the agreed plan and hand it back - do not start implementing, and do not ask "shall I build it now?" as a way to keep going. Reaching shared understanding is the end of this skill, not a checkpoint on the way to writing code. Implementation happens only when the user comes back and explicitly asks for it in a separate step.

If the agreed plan needs to outlive this session - picked up after a context clear or split across sessions - the user can invoke [[to-spec]] to capture it as a durable record. That is a separate step they choose, not something you roll into refining.
