# 0004. Write both series conventions

## Status

Accepted

## Context

Recorded retroactively; decided in the initial commit (81602e7). There is no single standard for series metadata in EPUBs.

- Option 1: Write only Calibre's `calibre:series` and `calibre:series_index` meta tags. Widely read, including by KOReader, but not part of the EPUB spec.
- Option 2: Write only EPUB 3's `belongs-to-collection` with `collection-type` and `group-position`. Standard, but ignored by many readers and tools.
- Option 3: Write both, updating existing tags in place.

## Decision

We will go with Option 3: setting a series writes both conventions, and clearing it removes both.

## Consequences

Series information shows up in the widest range of readers. Both conventions must be kept in step on every write, and books in the wild now carry both, so dropping one later would leave stale tags behind unless it is actively removed.
