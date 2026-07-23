# Contributing

Thanks for your interest in contributing to Rebind!

## Development setup

There is nothing to install beyond a Lua interpreter. The test suite is
zero-dependency — no luarocks, no busted — and stubs KOReader's `ffi/archiver`
with an in-memory archive so the pure-logic modules can be exercised off-device.

```bash
git clone https://github.com/rameezk/rebind.koplugin.git
cd rebind.koplugin
make test
```

`./tests/run.sh` picks the first interpreter it finds, trying `luajit`, `lua5.1`,
`lua`, and finally `nix run nixpkgs#luajit`. If you have Nix, you need nothing else.

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
| `main.lua`, `rebind/ui/diffpicker.lua` | — | Need a live KOReader runtime; exercised on-device |
| `rebind/vendor/` | — | Vendored SLAXML; please don't modify locally |

If you change a pure-logic module, add or update its spec. UI changes should be
tested on a real device (or a desktop KOReader install) and described in the PR.

Rebind mutates EPUB files in place, so changes touching the write path deserve
extra care — see the **Safety** section of the README for the temp-file, validate,
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
maintainer to approve the workflow run before it starts — that's a GitHub
default, not a comment on your patch.

## Releasing

Maintainers only. Releases are automated and cut from `main`, and gated on the
test suite — nothing is tagged or published unless `make test` passes on the
commit being released.

1. Merging a conventional commit into `main` causes release-please to open (or
   update) a release pull request titled `chore(main): release X.Y.Z`, containing
   the computed version bump and the `CHANGELOG.md` entries.
2. Review that pull request. It is the changelog — edit it there if the generated
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
