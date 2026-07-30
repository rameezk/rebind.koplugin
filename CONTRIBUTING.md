# Contributing

Thanks for your interest in contributing to Rebind!

## Development setup

There is nothing to install beyond a Lua interpreter. The test suite is
zero-dependency - no luarocks, no busted - and stubs KOReader's `ffi/archiver`
with an in-memory archive so the pure-logic modules can be exercised off-device.

```bash
git clone https://github.com/rameezk/rebind.koplugin.git
cd rebind.koplugin
make test
```

`./tests/run.sh` picks the first interpreter it finds, trying `luajit`, `lua5.1`,
`lua`, and finally `nix run nixpkgs#luajit`. If you have Nix, you need nothing else.

## Testing UI changes in the emulator

The pure-logic modules are covered by the test suite, but `main.lua` and the
diff picker need a live KOReader runtime. Instead of round-tripping to a real
device, run KOReader's macOS emulator with Rebind loaded:

```bash
make emulator          # download the emulator (once), then launch it
make emulator-update   # re-download the latest KOReader macOS build first
```

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
| `perf:` | patch | Performance |
| `refactor:` | patch | Refactoring |
| `docs:` | patch | Documentation |
| `test:` | patch | hidden |
| `ci:` | patch | hidden |
| `chore:` | patch | hidden |

Anything that isn't a breaking change or a `feat:` results in a patch bump, so
prefer `chore:` over `feat:` for housekeeping that users won't notice.

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
2. Review that pull request. It is the changelog - edit it there if the generated
   notes need wording help.
3. Merging it tags the release, publishes the GitHub Release, and the same
   workflow builds `dist/rebind.koplugin.zip` and attaches it to that release.

To force a specific version regardless of commit types, add a `Release-As:`
footer to a commit:

```
chore: prepare the 2.0.0 release

Release-As: 2.0.0
```

## Questions?

Open an issue if you have questions or run into problems.
