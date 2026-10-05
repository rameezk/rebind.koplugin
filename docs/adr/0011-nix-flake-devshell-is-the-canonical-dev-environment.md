# 0011. A Nix flake devshell is the canonical dev environment

## Status

Accepted

## Context

The forge software factory runs agents against this repo and gives each workload the toolchain from `devShells.<system>.default` (via `nix print-dev-env`). Without a flake, a workload gets only forge's base toolset and has no LuaJIT, so it cannot run `make test`. Forge does not surface a broken devshell loudly, so a broken flake must be caught before forge loads it. CI installed LuaJIT via apt, and the scripts fell back to unpinned `nix run nixpkgs#...`.

- Option 1: Add a flake for forge and local dev, and keep CI on apt. CI starts fastest, but nothing checks that the flake works, and the apt and nixpkgs LuaJIT builds can drift apart.
- Option 2: Add a flake, keep CI on apt for tests, and add a separate job that only evaluates the devshell. It catches a broken flake, but there are still two sources for the toolchain.
- Option 3: Add a flake and run CI through it (`nix develop -c make ...`), with no binary cache beyond cache.nixos.org. Local dev, CI and forge share one pinned toolchain. Each CI run costs an estimated 15-30s more (Nix install plus a ~98 MB `mkShellNoCC` closure, measured on x86_64-linux).

## Decision

We will go with Option 3: a plain `forAllSystems` flake with a `mkShellNoCC` default devShell for x86_64/aarch64 × linux/darwin, pinned to a stable nixpkgs release. The emulator's tools are added only on Darwin, and the unpinned `nix run` fallbacks are removed.

## Consequences

Every PR proves the devshell works, so forge and contributors can't silently end up with a broken environment. CI depends on Nix and on cache.nixos.org being reachable, and it is slightly slower than apt. Toolchain upgrades now happen by bumping `flake.lock`, not through the CI runner image. Contributors who don't use Nix can still install LuaJIT themselves.
