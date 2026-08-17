# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

An in-sim Navigraph Charts panel for **X-Plane 12**, built on
[SkyScript](https://github.com/x-z7a/SkyScript). The product is one file:
`apps/charts/manifest.yaml`. Everything else downloads a prebuilt plugin and
copies files next to it.

**SkyScript is X-Plane only — it can never target MSFS.** It is a CEF host built
against the X-Plane SDK (XPLM 4.2.0) that renders into X-Plane floating windows
and registers X-Plane commands and datarefs. MSFS in-sim panels are JS/HTML
gauges under the MSFS Avionics Framework, an unrelated host. "Like Navigraph
does in MSFS" is the analogy for the product, not the target platform.

## This repo compiles nothing

Do not add C++, CMake or a Node build here. SkyScript's *example* release ships
a built `.xpl` for all three platforms whose whole job is to scan `apps/` and put
each app in the Plugins menu — that is exactly the plugin we want, so
`scripts/build-release.sh` downloads it and assembles a folder around it.

Consequences worth knowing before proposing a change:

- **The SkyScript library ships beside the `.xpl`, not under `lib/`.** The macOS
  binary's only rpath is `@loader_path`, so a dylib left in `lib/mac_x64/` is one
  the plugin cannot find, and X-Plane reports a plugin that failed to load.
- **No CEF is packaged.** Since SkyScript v0.5.0 the library resolves the
  Chromium runtime X-Plane ships (`@executable_path/../Frameworks/...` on macOS).
  Bundling one adds ~200MB that would not be the copy that loads.
- **The plugin's identity is compiled in**: the Plugins menu says "SkyScript" and
  the signature is `com.x-z7a.SkyScript`. Renaming files does not change either.
- The SkyScript version is pinned in `scripts/skyscript-version.txt`; that file
  is the only place to edit to take a new version.

## Manifests fail silently

SkyScript ignores unknown manifest keys and drops a malformed app from the menu
with nothing in `Log.txt` explaining why, so a typo survives until someone
launches X-Plane. Run `make check` (`scripts/check-manifests.py`) after editing
any manifest — a hook runs it automatically on Write/Edit.

The format is flat `key: value` scalars only, with no nesting. The full field
list is in SkyScript's `docs/developer/manifest.md`.

## Custom window chrome is not available to a URL-only app

SkyScript draws its own chrome natively in C++ over the browser texture
(`src/include/components/browser/browser_handler.cpp`), and one app is one
browser is one top-level document. A branded header/footer around
`charts.navigraph.com` would require either an iframe (risking third-party
cookie breakage of Navigraph's login) or new C++ upstream in SkyScript. **We
chose stock chrome deliberately.** Do not reopen this by adding an iframe
wrapper without being asked.

Titleless windows already drag by the top strip and resize through X-Plane;
SkyScript v0.10.0 added a real title bar and resize grip.

## Testing means launching X-Plane

There are no unit tests and nothing to run headless. `make install` copies into
`~/X-Plane 12/Resources/plugins/zoal-charts` (override with `XPLANE_DIR`).
X-Plane reads the plugin folder once at startup, so a new build needs a restart;
manifest-only edits can use **Plugins → SkyScript → Reload configuration**.

Do not claim in-sim behaviour was verified — you cannot launch X-Plane. Say what
was checked (packaging, manifest validity) and what still needs a real flight.

## Local reference

SkyScript's source is checked out at `/Volumes/storage/git/skyScript`, and
`zoal-atc` (the other SkyScript consumer, whose packaging this mirrors) is at
`github.com/x-z7a/zoal-atc`. Read them before guessing at SkyScript's behaviour.
