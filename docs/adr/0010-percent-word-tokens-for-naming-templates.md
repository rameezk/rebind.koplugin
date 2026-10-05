# 0010. Percent-word tokens for naming templates

## Status

Accepted

## Context

Decided while refining #27. Custom templates are saved by users, so the syntax is hard to change once shipped. Templates also need a way to drop a segment, such as the series, when a book has no value for it.

- Option 1: Angle-bracket tokens, `<title>`. Can never collide with filename text, but unfamiliar to KOReader users.
- Option 2: KOReader's single-letter tokens, `%T`, `%A`, `%S`. Familiar from the footer and screensaver, but only three apply to books, the rest would be invented, and KOReader's `%A` means all authors.
- Option 3: Percent-word tokens, `%title`, `%author`. Familiar `%` style and readable on a small screen without a help page.

## Decision

We will go with Option 3. A token ends at the first character that is not a letter or `_`, `%%` is a literal percent sign, and `{…}` marks an optional group that is dropped when any token inside it is empty.

## Consequences

`%title{ - %series #%series_index} - %author{ (%year)}` expresses series-aware naming in one template. Literal `{`, `}` and `%` need escaping or are unavailable, and token names are frozen once users save templates that use them.
