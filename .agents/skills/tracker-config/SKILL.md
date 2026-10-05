---
name: tracker-config
description: Set up or change where a project's specs and work items are tracked. Use when configuring a tracker for the first time, checking an existing config is well-formed, or switching a project to a different tracker.
---

# Tracker Config

Own the `.tracker.toml` file at the project root - the single place that names where work is tracked. [[to-spec]] reads it to decide where a spec is published; this skill is what creates and maintains it.

## The file

`.tracker.toml` lives at the project root and holds two keys. A `local` project writes just:

```toml
type = "local"
```

A `github` project writes both keys:

```toml
type = "github"
repo = "owner/name"
```

- **`type`** - `local` keeps specs in the repo under `docs/specs/`; `github` publishes them as issues.
- **`repo`** - `owner/name` of the GitHub repository. Required for `github`, omitted for `local`.

Nothing else belongs in the file. Reject unknown keys rather than carrying them forward.

## Create

When no `.tracker.toml` exists, set one up:

1. Ask whether work is tracked **locally** or on **github**. Don't guess.
2. For `github`, infer the default `owner/name` from the current repository (`gh repo view --json nameWithOwner -q .nameWithOwner`), offer it as the default, and ask whether to use it or point at a different repo. If inference fails - no remote, not a GitHub repo, or `gh` unauthenticated - skip the default and ask the user for `owner/name` directly. Verify the chosen repo before writing (see below).
3. Write the file with only the keys that apply - no commented-out lines, no placeholders.

## Validate

When a `.tracker.toml` already exists, check it holds:

- valid TOML that parses at all - if it does not, treat it as a repair (create it afresh with the user) rather than running the checks below;
- exactly the known keys, nothing else;
- `type` set to `local` or `github`;
- `repo` present and shaped `owner/name` when `type = "github"`, absent otherwise;
- for `type = "github"`, that the repo actually resolves - run the same checks as the "Verifying a github repo" section below, so a renamed, deleted, or inaccessible repo surfaces here and not later inside [[to-spec]].

Report what is wrong and fix it with the user rather than silently rewriting.

## Switch

To move a project between destinations, rewrite the file for the new `type`: add `repo` (verified) when switching to `github`, drop it when switching to `local`. Switching does not migrate specs already written to the old destination; say so plainly and leave them where they are.

## Verifying a github repo

Before writing any `github` config, confirm the setup actually works, so the mistake surfaces here and not later inside [[to-spec]]:

```bash
gh auth status
gh repo view <owner/name> --json nameWithOwner
```

If `gh` is not authenticated, stop and ask the user to run `gh auth login`. If the repo does not resolve, stop and confirm the `owner/name` with the user. Only write the file once both pass.
