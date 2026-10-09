# 0013. Look up through a user-ordered Provider chain

## Status

Accepted

## Context

Users report that Hardcover's catalogue misses many of their books, so Rebind will look books up in more than one Provider. Providers differ in coverage, data quality and cost per lookup, and some have no Book and Edition split.

- Option 1: One active Provider, picked in settings. Simple, but the user has to guess which Provider holds each book.
- Option 2: A fixed fallback chain. Every lookup tries Providers in Rebind's order until one returns a Match.
- Option 3: A user-ordered fallback chain. The user enables Providers and orders them, and a lookup tries them in that order until one returns a Match.
- Option 4: Search every Provider and list all Matches together. Several network calls per lookup on a slow e-reader connection.
- Option 5: Merge Fields across Providers into one proposal. Blurs where each value came from and breaks the Book and Edition ownership of ADR-0005.

## Decision

We will go with Option 3. Each Match comes from exactly one Provider, and Fields are never merged across Providers. From the Source screen the user can also look the book up in any one enabled Provider, outside the chain. A Provider without Editions returns each result as a Book with exactly one Edition, so ADR-0005 and ADR-0012 apply to every Provider unchanged.

## Consequences

Users who know where their books are catalogued get there in one lookup, and a wrong or thin first Match is one tap from a lookup elsewhere. Rebind needs a Provider interface and a settings menu for enabling and ordering Providers. Every Provider is mapped onto the Book and Edition model, even when it is flat.
