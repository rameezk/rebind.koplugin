# 0009. Store the First published year in dc:date

## Status

Accepted

## Context

Decided while refining #27. Naming templates read only embedded metadata, so a year token needs the year in the EPUB. Hardcover offers the Book's original `release_year` and each Edition's full `release_date`.

- Option 1: Write the Edition's release date to `dc:date`. Matches the usual meaning of `dc:date` and ADR 0005, but a 2012 ebook of a 1983 novel files as 2012.
- Option 2: Write the Book's original year to `dc:date` as a bare `YYYY`, as a Book-owned Field. Stable across Edition switches and what people mean when filing by year.
- Option 3: Use Hardcover's year for naming only, without writing it. Nothing to show for manual edits or renames without a lookup.

## Decision

We will go with Option 2: a new First published Field, owned by the Book, written to `dc:date` as a year.

## Consequences

`dc:date` no longer describes the Edition's own printing, which other tools may display as the edition date. Reading a Current value takes the year from the `opf:event="publication"` date when present, otherwise the first `dc:date`.
