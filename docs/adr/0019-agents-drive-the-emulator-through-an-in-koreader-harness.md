# 0019. Agents drive the emulator through an in-KOReader harness

## Status

Accepted

## Context

Agents need to reproduce bugs end to end and capture before/after screenshots of Rebind's menus and dialogs. The emulator only ran on macOS and had no way for an agent to tap, type or capture it. Forge runs agents on headless Linux.

- Option 1: OS-level input. On Linux, use Xvfb and `xdotool`. On macOS, use `cliclick` and `screencapture`, which need Accessibility and Screen Recording permissions. That is two stacks, and agents tap blind at pixel coordinates.
- Option 2: A dev-only KOReader plugin that is linked into the emulator only and never packaged. It takes commands (tap by coordinates or by widget text, type, screenshot, dump the widget tree), injects them as KOReader input events, and saves screenshots from KOReader's own framebuffer. The same code runs on both OSes.
- Option 3: Both, with OS-level input as a fallback.

## Decision

We will go with Option 2. On Linux, the emulator uses the `linux-<arch>` tarball from the same KOReader master CI run the macOS build comes from, so both OSes run the same commit.

## Consequences

Agents use one documented workflow on macOS and Linux. They find controls by label, and nothing outside KOReader's framebuffer can end up in a screenshot. We own a small harness that depends on KOReader internals (input events, widget tree, framebuffer), so it can break when KOReader master changes. Downloading the Linux build needs an authenticated `gh`, the same as on macOS.
