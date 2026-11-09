# 0017. Look up every book before reviewing a bulk Rebind

## Status

Accepted

## Context

A bulk Rebind covers anything from a handful of books to a few hundred. A wrong Match silently overwrites good metadata, while reviewing every book in the Picker is slow at that size.

- Option 1: A queue that opens the Picker for each book in turn. Every write is reviewed, but a large batch takes as long as rebinding each book by hand.
- Option 2: Unattended writes of every Proposed value, then a summary. Fast, but wrong Matches are written with only the Backup to undo them.
- Option 3: Look up every book first, then show a review list with one row per book and its lookup outcome. A row opens the normal Picker for that book, and one action writes only the books whose Match is safe to accept unattended.

## Decision

We will go with Option 3. Lookups are throttled to respect Provider rate limits, cancelling keeps the results found so far for review, and a bulk Rebind does not resume across KOReader restarts.

## Consequences

Safe books take one tap and uncertain ones are never written without the user seeing them. Rebind needs a rule for which Matches count as safe to accept unattended, and a review list that scales to a few hundred rows. A batch interrupted by a restart has to be started again.
