# Screenshots

How to capture UI shots for [[before-after]]. Write every scratch file here -
the capture script, the images, test output - in a scratch directory outside the
repo, never in the repo itself.

## Running the app

Run the app the way the repo does - its README, a Makefile target, a package
script, or a project run skill - against seed or fixture data in a local or dev
environment. Wait until it is actually serving before capturing. Run the before
app, capture, stop it; then the after app. Note the URL each side is served on.

## Tooling

Use the first of these that is available:

1. **A browser automation tool already in the session** (a Playwright or
   Puppeteer MCP, say). Drive it through the same shot definitions: set the
   viewport and color scheme, navigate, perform the steps, screenshot.
2. **Playwright already installed** - `playwright` on `PATH`, or the repo's own
   dev dependency.
3. **Nothing available**: fetch Playwright one-off with nix. The nixpkgs
   package bundles its browsers, so nothing is installed globally:

   ```bash
   nix run nixpkgs#playwright-test -- <args>
   ```

Do the same for any other missing tool: `nix run nixpkgs#<package> -- <args>`,
or `nix shell nixpkgs#<package> -c <command>` for several commands. Never
install tools globally for this.

## Capture script

Write the shot definitions once as a Playwright spec and run it for each side
with a different `BASE_URL` and `SIDE`. One script for both sides is what keeps
each pair identical apart from the change.

```js
const { test } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL;
const SIDE = process.env.SIDE;
const OUT_DIR = process.env.OUT_DIR;

test.use({
  viewport: { width: 1280, height: 800 },
  deviceScaleFactor: 2,
  colorScheme: 'light',
  locale: 'en-US',
  timezoneId: 'UTC',
});

test('settings-save-button', async ({ page }) => {
  await page.goto(`${BASE_URL}/settings`);
  await page.getByRole('button', { name: 'Save' }).waitFor();
  await page.evaluate(() => document.fonts.ready);
  await page.getByTestId('settings-form').screenshot({
    path: `${OUT_DIR}/settings-save-button-${SIDE}.png`,
    animations: 'disabled',
    caret: 'hide',
  });
});
```

Run it from the scratch directory, once per side:

```bash
BASE_URL=http://localhost:3000 SIDE=before OUT_DIR="$PWD/shots" \
  nix run nixpkgs#playwright-test -- test capture.spec.js --reporter=line --output="$PWD/test-results"
```

With an already-installed Playwright, run `playwright test` the same way from a
directory where `@playwright/test` resolves.

A plain, URL-addressable state needs no script:

```bash
nix run nixpkgs#playwright-test -- screenshot \
  --viewport-size="1280, 800" --color-scheme=light --timezone=UTC --lang=en-US \
  --wait-for-selector="<ready-selector>" <url> <slug>-<side>.png
```

## Determinism

Anything that differs between the two runs other than the change turns a pair
into noise.

- Same viewport, device scale factor, color scheme, locale, timezone, and
  browser for both sides. Use `deviceScaleFactor: 2` so text stays crisp on the
  PR page.
- Same data: seed both sides identically. Avoid real clocks, random data, and
  relative times ("3 minutes ago") in frame; pin them via seed data or crop them
  out of the element being captured.
- Wait for a selector that means "ready" plus `document.fonts.ready`, not a
  fixed sleep. Disable animations and hide the caret.
- Dismiss cookie banners, toasts, and dev overlays before capturing, or they end
  up in one side and not the other.
- Log in with a fake local test account when a state needs auth - never real
  credentials, and never let session details show in frame.
