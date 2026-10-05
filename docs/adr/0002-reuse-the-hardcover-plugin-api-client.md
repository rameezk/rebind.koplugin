# 0002. Reuse the Hardcover plugin's API client

## Status

Accepted

## Context

Recorded retroactively; decided in the initial commit (81602e7). Lookups need an authenticated Hardcover GraphQL client.

- Option 1: Ship Rebind's own Hardcover client. Self-contained, but users configure an API token a second time and Rebind maintains its own HTTP and GraphQL plumbing.
- Option 2: Require `hardcoverapp.koplugin` and call its `hardcover_api` module. Users with it already set up need no extra configuration and Rebind writes no client code, but it becomes a hard dependency for lookups.

## Decision

We will go with Option 2: lookups go through `hardcoverapp.koplugin`'s API client, and queries it does not offer are sent through its `Api:query`.

## Consequences

No duplicate token setup and less code to maintain. Lookups break when that plugin is missing, disabled, unconfigured or changes its internal API, so Rebind must always offer manual editing as a fallback. Its bugs become Rebind's bugs, such as the forked subprocess crashing on macOS that `tools/emulator.sh` patches around.
