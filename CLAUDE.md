# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

An in-sim Navigraph Charts panel for **X-Plane 12**, built on
[SkyScript](https://github.com/x-z7a/SkyScript). Two small pieces: a thin C++
plugin (`src/main.cpp`) that hands SkyScript the `apps/` directory and builds a
menu, and the app itself (`apps/charts/manifest.yaml`) — a URL-only SkyScript
app, so there is no HTML, no JavaScript and no frontend build.

**SkyScript is X-Plane only — it can never target MSFS.** It is a CEF host built
against the X-Plane SDK that renders into X-Plane floating windows and registers
X-Plane commands and datarefs. MSFS in-sim panels are JS/HTML gauges under the
MSFS Avionics Framework, an unrelated host. "Like Navigraph does in MSFS" is the
analogy for the product, not the target platform.

## Build and test

```sh
make deps       # X-Plane SDK + pinned SkyScript bundle into .cache/
make plugin     # build zoal-charts.xpl for this platform
make package    # assemble dist/zoal-charts
make install    # package, then install into ~/X-Plane 12 (XPLANE_DIR overrides)
make check      # validate apps/*/manifest.yaml
make lint       # shellcheck + ruff, via uvx when not installed
```

A local SDK checkout is reused with `ZOAL_CHARTS_SDK_ROOT=/Volumes/storage/git/SDK`,
which saves the download.

**One platform can only be built on itself.** `make package` warns and packages
what it has; CI builds all three and packaging refuses to publish a partial tree
when `ZOAL_CHARTS_REQUIRE_ALL_PLATFORMS=1`.

**There are no unit tests, and X-Plane cannot be launched from here.** Say what
was checked (it compiled, it packaged, the manifest is valid) and leave in-sim
behaviour to the user. Do not claim the panel works.

## Things that will bite

- **The SkyScript library ships beside the `.xpl`, not under `lib/`.** The macOS
  binary's only rpath is `@loader_path`. A dylib left in `lib/mac_x64/` is one
  the plugin cannot find, and X-Plane reports a plugin that failed to load.
- **No CEF is packaged.** Since SkyScript v0.5.0 the library resolves the
  Chromium runtime X-Plane ships. Bundling one adds ~200MB that would not even
  be the copy that loads.
- **Assets are not in the SkyScript lib bundle.** They come from the source
  tarball at the same tag (828KB, versus 140MB for the example release that also
  has them). A release without `assets/` is a plugin with no back button.
- **Identity is compiled in** (`src/config.h`): name `zoal-charts`, signature
  `com.x-z7a.zoal-charts`. It must stay distinct from `com.x-z7a.SkyScript` —
  X-Plane loads only one plugin per signature.
- **SkyScript's mac binaries are arm64-only**, so there is no Intel Mac support
  to offer.
- The SkyScript version is pinned in `scripts/skyscript-version.txt`; that file
  is the only place to edit to take a new version.

## Manifests fail silently

SkyScript ignores unknown manifest keys and drops a malformed app from the menu
with nothing in `Log.txt` explaining why, so a typo survives until someone
launches X-Plane. Run `make check` after editing any manifest — a hook runs it
automatically on Write/Edit.

The format is flat `key: value` scalars only, with no nesting. The full field
list is in SkyScript's `docs/developer/manifest.md`.

## Custom window chrome was considered and rejected

SkyScript draws its own chrome natively in C++ over the browser texture, and one
app is one browser is one top-level document. A branded header/footer around
`charts.navigraph.com` would need either an iframe (risking third-party cookie
breakage of Navigraph's login) or new C++ upstream in SkyScript. **Stock chrome
is a deliberate choice.** Do not add an iframe wrapper without being asked.

Titleless windows already drag by the top strip and resize through X-Plane;
SkyScript v0.10.0 added a real title bar and resize grip.

## Local reference

SkyScript's source is checked out at `/Volumes/storage/git/skyScript`, and the
X-Plane SDK at `/Volumes/storage/git/SDK`. `zoal-atc` (the other SkyScript
consumer, whose packaging this mirrors) is at `github.com/x-z7a/zoal-atc`. Read
them before guessing at SkyScript's behaviour.
