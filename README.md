# zoal-charts

An in-sim Navigraph Charts panel for **X-Plane 12** — a floating, resizable
window you can read charts in, in any aircraft, because it belongs to the plugin
rather than to a cockpit.

Built on [SkyScript](https://github.com/x-z7a/SkyScript), which hosts web content
in X-Plane windows through CEF.

> You need your own Navigraph subscription. This plugin opens
> `charts.navigraph.com` in the sim; it does not bundle, cache or redistribute
> any chart data.

## Install

1. Download the release archive and unzip it.
2. Drop the `zoal-charts` folder into `<X-Plane 12>/Resources/plugins/`.
3. Launch X-Plane, then open **Plugins → zoal-charts → Navigraph Charts** and
   sign in to Navigraph.

Drag the window by the strip along its top edge, and resize it from the grip in
the corner.

The archive ships no CEF: SkyScript resolves the Chromium runtime that comes with
X-Plane 12, so there is nothing ~200MB to download that X-Plane already has.

macOS builds are **Apple Silicon only** — the SkyScript library ships arm64.

## Build

```sh
make deps       # fetch the X-Plane SDK and the pinned SkyScript bundle
make plugin     # build zoal-charts.xpl for this platform
make package    # assemble dist/zoal-charts
make install    # package, then install into ~/X-Plane 12
make archive    # package, then zip it
make check      # validate every apps/*/manifest.yaml
make lint       # shellcheck + ruff
```

`make install` takes `XPLANE_DIR=...` if X-Plane is not at `~/X-Plane 12`, and
`ZOAL_CHARTS_SDK_ROOT=...` reuses an SDK you already have instead of downloading
one.

A plugin can only be built on the platform it runs on, so a local `make package`
covers this machine and says which platforms it left out. CI builds all three.

The SkyScript version is pinned in `scripts/skyscript-version.txt`. Editing that
file is how you take a new SkyScript.

## Release

Push a tag:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

`.github/workflows/release.yml` builds on macOS, Windows and Linux, packages all
three into one archive, checks each platform carries both its `.xpl` and the
SkyScript library beside it, and publishes the release. Packaging refuses to run
if any platform is missing, so a partial release cannot be published by accident.

`workflow_dispatch` runs the same build and leaves the archive as an artifact
without publishing, which is how to rehearse a release.

## What is actually in here

```
src/main.cpp                the plugin: hand SkyScript apps/, build a menu
src/config.h                the compiled-in name and signature
apps/charts/manifest.yaml   the panel: a URL-only SkyScript app
scripts/ensure-deps.sh      fetch the SDK and the pinned SkyScript bundle
scripts/build-release.sh    assemble dist/zoal-charts
scripts/check-manifests.py  catch manifest typos, which otherwise fail silently
```

## Licence

`src/main.cpp` is adapted from SkyScript's example plugin (MIT). The SkyScript
library redistributed in each release is MIT, included at
`licenses/skyscript/LICENSE`.
