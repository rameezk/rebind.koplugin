# 0001. Rewrite the embedded OPF instead of a KOReader sidecar

## Status

Accepted

## Context

Recorded retroactively; decided in the initial commit (81602e7). KOReader readers and other apps read metadata from different places, and corrections should follow the file.

- Option 1: Store corrected metadata in KOReader's `.sdr` sidecar or settings. Non-destructive, but only KOReader on this device sees it.
- Option 2: Rewrite the OPF inside the EPUB, as Calibre does. Every reader and device sees the change, but Rebind mutates user files.

## Decision

We will go with Option 2: Rebind edits the OPF metadata in the EPUB itself.

## Consequences

Corrected metadata travels with the file to Calibre, other readers and other devices. Every change to the write path carries the risk of corrupting a user's book, which is why ADR-0003 exists. Formats other than EPUB need their own writer before they can be supported.
