# Contributing

Thanks for your interest in contributing to Rebind!

## Development setup

The repo's Nix flake devshell provides the pinned toolchain (LuaJIT, make, zip,
git and gh). Enter it with `nix develop`, or let [direnv](https://direnv.net)
load it through the committed `.envrc`. CI and forge use the same devshell.

The test suite is zero-dependency - no luarocks, no busted - and stubs
KOReader's `ffi/archiver` with an in-memory archive so the pure-logic modules can
be exercised off-device.

```bash
git clone https://github.com/rameezk/rebind.koplugin.git
cd rebind.koplugin
nix develop -c make test
```

Without Nix, install LuaJIT yourself (`luajit`, `lua5.1` or `lua` on your
`PATH`) and run `make test`. `./tests/run.sh` exits with an error pointing to
`nix develop` when it finds no interpreter.

## Testing UI changes in the emulator

The pure-logic modules are covered by the test suite, but `main.lua` and the
diff picker need a live KOReader runtime. Instead of round-tripping to a real
device, run KOReader's macOS emulator with Rebind loaded. Run it from inside the
devshell: on macOS it also provides the 7-Zip, unzip and python3 the emulator
script needs to unpack KOReader and the Hardcover plugin.

```bash
nix develop
make emulator          # download the emulator (once), then launch it
make emulator-update   # re-download the latest KOReader macOS build first
```

Without Nix, install `7zz` (or `7z`), `unzip` and `python3` yourself. The script
exits with an error pointing to `nix develop` when one of them is missing.

The emulator is KOReader's official macOS build, pulled from the project's CI
via the `gh` CLI (so `gh auth login` must have been run once) and unpacked into
`.emulator/` (gitignored). Rebind is **symlinked** into it, so edits to
`main.lua` and `rebind/*.lua` take effect on the next launch - no rebuild.

KOReader opens in `.emulator/books/`, seeded on first run with a sample EPUB
whose author is `Unknown` so there's something to rebind immediately. Drop your
own EPUBs there to test against - Rebind mutates files in place, so keep it away
from your real library while iterating.

To exercise **live Hardcover lookups** (not just the manual-edit fallback), give
the script a [Hardcover API token](https://hardcover.app/account/api) - the part
after `Bearer`. It installs and configures the Hardcover plugin for you:

```bash
make emulator-token        # prompts for the token (input hidden), saves it locally
# or, per-session, without saving it to disk:
HARDCOVER_TOKEN=xxxxx make emulator
```

> **macOS note.** The Hardcover plugin runs every API call inside
> `Trapper:dismissableRunInSubprocess`, which `fork()`s. On macOS the forked child
> segfaults the moment it touches Apple's `Network.framework` (`SIGSEGV` in
> `nwlog_legacy_init`), so the parent gets nothing back and **every lookup reports
> "No match found"** while quietly filling `~/Library/Logs/DiagnosticReports` with
> koreader crash reports. `tools/emulator.sh` patches the downloaded copy to query
> in-process so the emulator works. This only touches `.emulator/` - the plugin on a
> real device is untouched, and the bug belongs upstream in hardcoverapp.koplugin.

The token is read from `$HARDCOVER_TOKEN` or from `.emulator/hardcover_token`
(`chmod 600`), and the generated `hardcover_config.lua` is written under
`.emulator/`. **All of this is gitignored** - the token never enters the repo. If
no token is found, Rebind simply offers manual editing, as it does on-device when
Hardcover is missing.

For a foreground run that streams KOReader's logs to your terminal (handy when a
change misbehaves), use `./tools/emulator.sh --console`.

This currently targets macOS (Apple Silicon and Intel). On Linux, use the
distro's KOReader package or an AppImage and drop the plugin into its `plugins/`
folder.

## Available targets

```
make test      # run the test suite
make package   # run tests, then build dist/rebind.koplugin.zip
make clean     # remove build artifacts
```

## Project layout

| Path | Tested by | Notes |
|------|-----------|-------|
| `rebind/epub.lua` | `tests/epub_spec.lua` | OPF editing, metadata/ISBN extraction |
| `rebind/hardcover.lua` | `tests/hardcover_spec.lua` | Hardcover lookup and extraction |
| `rebind/organize.lua` | `tests/organize_spec.lua` | Destination path logic |
| `rebind/translate.lua` | `tests/translate_spec.lua` | Language targets, batching, text chunking |
| `main.lua`, `rebind/ui/diffpicker.lua` | - | Need a live KOReader runtime; exercise via `make emulator` (or on-device) |
| `rebind/vendor/` | - | Vendored SLAXML; please don't modify locally |

If you change a pure-logic module, add or update its spec. UI changes should be
tested on a real device (or a desktop KOReader install) and described in the PR.

Rebind mutates EPUB files in place, so changes touching the write path deserve
extra care - see the **Safety** section of the README for the temp-file, validate,
backup, atomic-replace sequence that must be preserved.

## Commit messages

This project uses [release-please](https://github.com/googleapis/release-please)
for automated versioning and changelog generation, so commit messages are
load-bearing. Please use
[conventional commits](https://www.conventionalcommits.org/).

| Prefix | Version bump | Changelog section |
|--------|--------------|-------------------|
| `feat:` | minor | Features |
| `fix:` | patch | Bug Fixes |
| `perf:` | patch | hidden |
| `refactor:` | patch | hidden |
| `docs:` | patch | hidden |
| `test:` | patch | hidden |
| `ci:` | patch | hidden |
| `chore:` | patch | hidden |

Only Features and Bug Fixes appear in the release notes. A run of only hidden
commits does not open a release pull request at all; those commits ship with the
next `feat` or `fix` and stay out of its notes.

### Which type to use

`feat` and `fix` are only for changes a person using Rebind on the device would
notice. Everything else uses `chore`, `ci`, `test` or `docs`: tooling, the
devshell, the emulator, CI, tests, refactors and contributor docs. A speed-up
someone would notice is a `feat` or `fix` worded around its effect ("opening the
picker is faster on large libraries"), not around how it was done.

### Writing a `feat` or `fix` title

The pull request title becomes the changelog line, so write it as a plain
sentence about what changed for the person holding the device:

- Describe the change from the user's point of view.
- Name the screens and actions they can see.
- Never name modules, functions or refactors.
- Use the terms in `docs/CONTEXT.md` as plain lowercase words, never as capitalised proper nouns.
- Keep the Conventional Commit format: `type: lowercase subject`, no trailing period.

| Instead of | Write |
|------------|-------|
| `feat: add the Save as summary and screen, rename-only Apply and name-clash check` | `feat: choose the folder, filename and backup on one screen` |
| `feat: redesign the Picker Field list with radio values, tags, fold and bulk button` | `feat: pick each field's value from a simpler list` |
| `fix: make Hardcover lookups work in the macOS emulator` | `chore: make Hardcover lookups work in the macOS emulator` |
| `feat: add a nix flake devshell as the canonical dev environment` | `chore: add a nix flake devshell as the canonical dev environment` |

### Breaking changes

Breaking changes bump the major version. Mark them with a `!` after the type, or
with a `BREAKING CHANGE:` footer:

```
feat!: drop support for the legacy series tags

BREAKING CHANGE: EPUBs written by versions before 1.0 need re-rebinding.
```

Examples:

```
feat: write cover images from Hardcover
fix: handle an OPF with no metadata element
docs: clarify the Hardcover token setup
```

## Submitting changes

1. Fork the repository
2. Create a branch (`git checkout -b feat/my-feature`)
3. Make your changes and keep `make test` green
4. Commit using conventional commits
5. Push to your fork and open a pull request

CI runs the test suite on every pull request. First-time contributors need a
maintainer to approve the workflow run before it starts - that's a GitHub
default, not a comment on your patch.

## Releasing

Maintainers only. Releases are automated and cut from `main`, and gated on the
test suite - nothing is tagged or published unless `make test` passes on the
commit being released.

1. Merging a conventional commit into `main` causes release-please to open (or
   update) a release pull request titled `chore(main): release X.Y.Z`, containing
   the computed version bump and the `CHANGELOG.md` entries.
2. Review that pull request. Check the version and that every line in the
   notes reads as a change a person on the device would notice. Fix a wrong line
   at its source with a commit override (see below), not by editing the release
   pull request: release-please rebuilds that pull request on every merge into
   `main`, so edits made there are overwritten.
3. Merging it tags the release, publishes the GitHub Release, and the same
   workflow builds `dist/rebind.koplugin.zip` and attaches it to that release.

To force a specific version regardless of commit types, release-please needs to
see a `Release-As:` footer on a commit in `main`. Pull requests are
squash-merged and the squash commit keeps only the pull request title, so a
footer on a branch commit never reaches `main`. Put it in the pull request body
instead, inside a commit override block, which release-please reads in place of
the squash commit message:

```
BEGIN_COMMIT_OVERRIDE
chore: prepare the 2.0.0 release (#NN)

Release-As: 2.0.0
END_COMMIT_OVERRIDE
```

The block replaces the whole message for that pull request, so its first line
must be a conventional commit header. Keep the pull request number, written
here as `(#NN)`, so the changelog entry still links to it. Only maintainers
should add override blocks. A maintainer can still add one after the pull
request is merged, as long as it has not been released yet. It takes effect the
next time something is merged into `main`. Always check the version and
changelog in the release pull request before merging it.

### Rewording or retyping a changelog line

Maintainers only. The same override block fixes a merged pull request whose title does not read
well, or whose type is wrong. Only the header line reaches the changelog, and
the type on it decides the section. Rewrite the header, or change `feat` or
`fix` to `chore` to drop the line from the notes. Separate every entry with a
blank line, otherwise release-please reads them as one:

```
BEGIN_COMMIT_OVERRIDE
feat: choose the folder, filename and backup on one screen (#67)

chore: add the name-clash check (#67)
END_COMMIT_OVERRIDE
```

An override block belongs to one merged pull request and replaces its whole
message, so list every entry that pull request should leave in the changelog.

### Hand-written release notes

For a big release the maintainer may replace the generated notes with
hand-written ones, the way 2.0.0 was done. Do this as the very last step before
merging the release pull request, and only when nothing else will merge into
`main` first - the next merge makes release-please rebuild the pull request and
overwrite the text.

1. Replace the text between the `---` lines in the release pull request body.
   It becomes the GitHub Release, which Storefront shows on its details screen.
2. Commit the same text to `CHANGELOG.md` on the release branch.
3. Merge the release pull request straight away.

Follow the 2.0.0 style: an intro sentence, then bullets that open with a bold
phrase. Avoid underscores in plain text, which Storefront italicises. Agents
never edit `CHANGELOG.md`; this is a maintainer step.

## Questions?

Open an issue if you have questions or run into problems.
