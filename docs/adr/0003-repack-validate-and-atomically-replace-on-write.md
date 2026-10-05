# 0003. Repack, validate and atomically replace on write

## Status

Accepted

## Context

Recorded retroactively; decided in the initial commit (81602e7). ADR-0001 means Rebind overwrites user files, and a half-written EPUB loses the book.

- Option 1: Write the edited EPUB straight over the original. Simple, but a crash or bad edit destroys the book.
- Option 2: Repack the whole archive to a temporary file, validate it (the `mimetype` entry first and stored, the OPF parses), copy the original to a Backup, then rename the temporary file over the original.
- Option 3: Patch only the OPF entry inside the existing zip. Faster on large books, but not weighed at the time.

## Decision

We will go with Option 2, and every change to the write path must preserve this sequence.

## Consequences

The original is never touched until a valid replacement exists, and a Backup always exists during the swap. Every Rebind rewrites every entry in the archive, which costs time and temporary disk space proportional to the book's size. Whether the Backup is kept afterwards is a user setting.
