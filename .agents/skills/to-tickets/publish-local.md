# Publish: local

Write one file per ticket under `docs/specs/NNNN-slug/tickets/NNNN.NN-slug.md`, beside the spec it slices. The `NNNN-slug` is the parent spec's own folder - reuse it, never allocate a new number.

- **Identity** - a compound ID `NNNN.NN`: the parent spec's 4-digit number, then the ticket's own 2-digit number. Scan the spec's `tickets/` folder for the highest existing `.NN` and continue from there; start at `01` only when it is empty, so re-running on an already-sliced spec appends rather than colliding. The ID alone links the ticket to its spec (`0001.02`). Use it in the filename, the H1, and every "Blocked by" reference to a sibling.
- **Status** - the file is the source of truth; there is no issue state to close. Write the `ready-for-agent` / `ready-for-human` value into the ticket's `Status`. `done` is recorded by setting `Status: done` - done by the dispatch step, never here.
- **Blocking edges** - list the blocking siblings' compound IDs in "Blocked by". Blocked-ness is not a stored status; it is derived from these edges - a ticket is blocked while any ID in its "Blocked by" is not yet `done`. There is no engine to maintain a separate flag, so keeping the edge as the only source of truth is what stops it drifting.
