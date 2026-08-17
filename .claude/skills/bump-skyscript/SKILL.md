---
name: bump-skyscript
description: Move the pinned SkyScript version to a newer release and re-package. Use when the user wants to take a new SkyScript, upgrade the plugin binary, or asks what changed upstream.
disable-model-invocation: true
---

Taking a new SkyScript is this repo's main recurring change — it was the only
change in zoal-atc v0.3.0. `$ARGUMENTS` is the target version (e.g. `v0.11.0`);
with no argument, use the latest release.

## Steps

1. Read the current pin and find what is available:

   ```sh
   cat scripts/skyscript-version.txt
   gh release list --repo x-z7a/SkyScript --limit 10
   ```

2. Show the user what they would be taking before changing anything — the
   release notes are the only place the behaviour change is described:

   ```sh
   gh release view <version> --repo x-z7a/SkyScript
   ```

   Read the notes for anything affecting a **URL-only app**: window decoration,
   the address bar, manifest fields, how CEF is resolved, or the layout of the
   `SkyScript-example-*-XP12.zip` archive. Packaging reads that layout directly,
   so a reorganised archive breaks `scripts/build-release.sh`.

3. Try it without moving the pin first:

   ```sh
   ZOAL_CHARTS_SKYSCRIPT_VERSION=<version> make package
   ```

   A failure here is the archive layout having changed. Fix
   `scripts/build-release.sh` to match the new layout rather than working around
   it.

4. If that packaged cleanly, move the pin:

   ```sh
   printf '%s\n' "<version>" > scripts/skyscript-version.txt
   make package
   ```

5. Check any new manifest fields worth adopting, then re-validate:

   ```sh
   grep -A2 '^| `' /Volumes/storage/git/skyScript/docs/developer/manifest.md
   make check
   ```

## Then tell the user

Summarise what changed upstream and whether it affects a URL-only app. Say
plainly that the new binary is unverified in the sim: packaging succeeding
proves the files are in the right places, not that the panel opens.
