# zoal-charts

An in-sim Navigraph Charts panel for **X-Plane 12** — a floating, resizable
window you can read charts in, in any aircraft, because it belongs to the
plugin rather than to a cockpit.

Built on [SkyScript](https://github.com/x-z7a/SkyScript), which hosts web content
in X-Plane windows through CEF.

> You need your own Navigraph subscription. This plugin opens
> `charts.navigraph.com` in the sim; it does not bundle, cache or redistribute
> any chart data.

## Install

1. Download the release archive and unzip it.
2. Drop the `zoal-charts` folder into `<X-Plane 12>/Resources/plugins/`.
3. Launch X-Plane, then open **Plugins → SkyScript → Apps → Navigraph Charts**
   and sign in to Navigraph.

Drag the window by the strip along its top edge, and resize it from the grip in
the corner.

The archive ships no CEF: SkyScript resolves the Chromium runtime that comes
with X-Plane 12, so there is nothing ~200MB to download that X-Plane already
has.

### Known limitation

The plugin binary is SkyScript's stock example build, so X-Plane identifies it
as **SkyScript** (signature `com.x-z7a.SkyScript`) rather than as zoal-charts —
that is the name the Plugins menu shows. Installing this alongside another
plugin built from the same example gives X-Plane two plugins with one signature,
and it will load only one of them. Changing that means building our own `.xpl`,
which is a real cross-platform toolchain and deliberately not what this repo
does today.

## Build

The repo compiles nothing. A release is SkyScript's prebuilt plugin plus our
manifest, so building it is a download and a copy:

```sh
make package    # assemble dist/zoal-charts
make install    # package, then install into ~/X-Plane 12
make archive    # package, then zip it for a release
make check      # validate every apps/*/manifest.yaml
```

`make install` takes `XPLANE_DIR=...` if X-Plane is not at `~/X-Plane 12`.

The SkyScript version is pinned in `scripts/skyscript-version.txt`. Editing that
file is how you take a new SkyScript.

## What is actually in here

```
apps/charts/manifest.yaml   the product: a URL-only SkyScript app
scripts/build-release.sh    download the pinned SkyScript, assemble dist/
scripts/check-manifests.py  catch manifest typos, which otherwise fail silently
```

## Licence

The plugin binary and library are SkyScript's, redistributed under the MIT
licence included at `licenses/skyscript/LICENSE` in every release.
