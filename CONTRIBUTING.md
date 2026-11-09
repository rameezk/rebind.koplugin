# Contributing

Thanks for your interest in contributing to Rebind!

## Development setup

The repo's Nix flake devshell provides the pinned toolchain (LuaJIT, make, zip,
git and gh). Enter it with `nix develop`, or let [direnv](https://direnv.net)
load it through the committed `.envrc`. CI and forge use the same devshell.

The test suite is zero-dependency - no luarocks, no busted - and stubs
KOReader's `ffi/archiver` with an in-memory archive so the pure-logic modules can
be exercised off-device. `tests/plugin_spec.lua` loads `main.lua` the way
KOReader's PluginLoader does, with every KOReader module it needs stubbed.

```bash
git clone https://github.com/rameezk/rebind.koplugin.git
cd rebind.koplugin
nix develop -c make test
```

Without Nix, install LuaJIT yourself (`luajit`, `lua5.1` or `lua` on your
`PATH`) and run `make test`. `./tests/run.sh` exits with an error pointing to
`nix develop` when it finds no interpreter.

## Testing UI changes in the emulator

The pure-logic modules are covered by the test suite, but Rebind's menus and
dialogs need a live KOReader runtime. Instead of round-tripping to a real
device, run KOReader's emulator with Rebind loaded. It runs on macOS and Linux,
with a window or without one, and this section is the how-to for humans and
agents alike. Run it from inside the devshell: it provides what the emulator
script needs to unpack KOReader and the Hardcover plugin (unzip everywhere, plus
7-Zip and python3 on macOS and xz on Linux), and on Linux the glibc loader that lets
KOReader's bundled binaries run on machines without a standard `/lib64`.

```bash
nix develop
make emulator            # download the emulator (once), then open it in a window
make emulator-headless   # no window, for headless Linux and agents
make emulator-stop       # exit KOReader cleanly
make emulator-update     # re-download the latest KOReader build first
```

Without Nix, install `unzip` plus `7zz` (or `7z`) and `python3` (macOS) or `xz`
(Linux) yourself. The script exits with an error pointing to
`nix develop` when one of them is missing.

The emulator is KOReader's master build, pulled from the project's CI via the
`gh` CLI (so `gh auth login` must have been run once) and unpacked into
`.emulator/` (gitignored): the macOS build on macOS, the `linux-<arch>` tarball
on Linux. Both come from the same latest successful CI run. Rebind is
**symlinked** into it, so edits to `main.lua` and `rebind/*.lua` take effect on
the next start - no rebuild. The dev-only harness in `tools/harness.koplugin`
is linked in too; it is never packaged with Rebind.

### Headless mode and screenshots

`start --headless` opens no window. KOReader renders through SDL3's `offscreen`
video driver on a fixed 1072x1448, 300 dpi screen, so screenshots match across
runs and across macOS and Linux. It needs no display server, and the command
returns once the harness is ready and the file browser is showing. Each headless
start uses a clean KOReader settings directory under `.emulator/headless-home/`.

```bash
./tools/emulator.sh start --headless
./tools/emulator.sh screenshot shot.png   # 1072x1448 PNG of what KOReader shows
./tools/emulator.sh stop
./tools/emulator.sh --help                # every subcommand and option
```

`screenshot` is taken from KOReader's own framebuffer, so nothing outside
KOReader can end up in it, and it returns only after the screen has settled.
The command line talks to the harness through a private spool directory,
`.emulator/spool/`; that protocol is not a contract, only the subcommands are.
A plain `./tools/emulator.sh` (or `make emulator`) is `start` without
`--headless` and opens KOReader's normal window, on a Linux desktop too.

### Driving the emulator

A running emulator, headless or windowed, can be driven the way a person would
drive the device. Every command returns only once KOReader has handled it and
the screen has settled, so the next command sees the result.

```bash
./tools/emulator.sh dump                  # every visible widget, with label and coordinates
./tools/emulator.sh tap 536 40            # tap at x y
./tools/emulator.sh tap "Rebind ▸"        # tap the one widget with that label
./tools/emulator.sh type "Jane Austen"    # type into the focused text field
./tools/emulator.sh key Enter             # press a key: Enter, Back, Backspace, Left, Right...
```

`dump` prints one line per widget: its label in quotes, then `x`, `y`, `w` and
`h` in pixels, for example `"Rebind ▸" x=9 y=97 w=229 h=81`. Text and menu
entries are labelled with their text (menu entries that open a submenu end in
` ▸`), text fields with their content or hint, and icon buttons with their icon
name, such as `appbar.menu`. Only the topmost window that takes input is
listed, plus what shows beneath it.

`tap "<label>"` matches the label exactly, as `dump` prints it. A label that
matches nothing, or more than one widget, fails with an error that says which
and sends no input; use `tap <x> <y>` when a label is ambiguous. Arguments
cannot contain newlines (press Enter with `key`), and `--` ends option parsing
for an argument that starts with a dash.

A typical session opens the menu, finds Rebind and goes in:

```bash
./tools/emulator.sh start --headless
./tools/emulator.sh tap 536 40            # tap the top of the screen: opens the menu
./tools/emulator.sh tap appbar.tools      # the tab that holds Rebind
./tools/emulator.sh tap "Rebind ▸"
./tools/emulator.sh dump                  # lists "Rebind current book" and "Lookup providers"
./tools/emulator.sh screenshot rebind.png
./tools/emulator.sh stop
```

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
> The patch applies on macOS only.

The token is read from `$HARDCOVER_TOKEN` or from `.emulator/hardcover_token`
(`chmod 600`) on both macOS and Linux, and the generated `hardcover_config.lua` is
written under `.emulator/`. **All of this is gitignored** - the token never enters
the repo. If no token is found, Rebind simply offers manual editing, as it does
on-device when Hardcover is missing.

For a foreground run that streams KOReader's logs to your terminal (handy when a
change misbehaves), use `./tools/emulator.sh start --console`. Background runs log
to `.emulator/koreader.log`.

The harness depends on KOReader internals (input events, the widget tree and the
framebuffer), so it may break when KOReader master changes. The `emulator smoke`
CI job boots the emulator headless, checks that `dump` lists Rebind's menu entry and
that tapping it by label opens Rebind's screen, and uploads a screenshot, on
every pull request that touches the emulator script, the harness or the flake,
and once a day; a failed daily run opens or updates an issue.

## Available targets

```
make test               # run the test suite
make package            # run tests, then build dist/rebind.koplugin.zip
make clean              # remove build artifacts
make emulator           # open the KOReader emulator in a window
make emulator-headless  # start it with no window
make emulator-stop      # stop it
```

## Project layout

| Path | Tested by | Notes |
|------|-----------|-------|
| `rebind/epub.lua` | `tests/epub_spec.lua` | OPF editing, metadata/ISBN extraction |
| `rebind/hardcover.lua` | `tests/hardcover_spec.lua` | Hardcover lookup and extraction |
| `rebind/organize.lua` | `tests/organize_spec.lua` | Destination path logic |
| `rebind/translate.lua` | `tests/translate_spec.lua` | Language targets, batching, text chunking |
| `main.lua` | `tests/plugin_spec.lua` | Loaded the way KOReader's PluginLoader loads it; menus and dialogs still need `make emulator` (or on-device) |
| `rebind/ui/diffpicker.lua` | - | Needs a live KOReader runtime; exercise via `make emulator` (or on-device) |
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
