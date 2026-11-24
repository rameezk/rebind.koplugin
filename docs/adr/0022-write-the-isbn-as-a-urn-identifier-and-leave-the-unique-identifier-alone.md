# 0022. Write the ISBN as a URN identifier and leave the unique identifier alone

## Status

Accepted

## Context

ISBN becomes a Field Rebind writes. EPUBs hold ISBNs in `dc:identifier`, and readers look for them in different forms: EPUB 3 expects `urn:isbn:<n>`, while EPUB 2 tools such as Calibre also read `opf:scheme="ISBN"`. Some books use their ISBN identifier as the package's `unique-identifier`, which readers and sync services use to recognise the book.

- Option 1: Write one `dc:identifier` holding `urn:isbn:<n>`, adding `opf:scheme="ISBN"` in EPUB 2 packages. Update an existing ISBN identifier in place, and never change or remove the one named by `unique-identifier`.
- Option 2: Write only the EPUB 3 `urn:isbn:` form. Simpler, but older tools miss it.
- Option 3: Rewrite every ISBN identifier, including the unique identifier. Consistent, but changing the book's identity can break reading progress and sync elsewhere.

## Decision

We will go with Option 1.

## Consequences

The ISBN is read by the widest range of tools. A book whose unique identifier is an ISBN may carry two ISBN identifiers after a Rebind that changes it, and clearing the ISBN Field leaves the unique identifier in place.
