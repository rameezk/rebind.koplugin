# 0007. Rename the file to "Author - Title" by default

## Status

Accepted

## Context

Recorded retroactively; decided in #24 (92ccd81). Filenames from stores and downloads rarely match the corrected metadata, and Sort already uses a surname-first author.

- Option 1: Never rename. Safe, but the filename stays wrong after the metadata is fixed.
- Option 2: Rename only when Sorting. Ties two unrelated wishes together.
- Option 3: Rename to `<Author, surname-first> - <Title>.<ext>` independently of Sort, controlled by a toggle that is on by default.

## Decision

We will go with Option 3. Collisions are refused rather than overwritten, and the `.sdr` sidecar follows the new name.

## Consequences

Libraries get consistent, sortable filenames without extra steps. Users who never touch the toggle have their files renamed, which is costly to undo across a library, so changing the scheme later would leave mixed filenames behind.
