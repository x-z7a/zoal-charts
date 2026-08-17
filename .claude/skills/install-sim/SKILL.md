---
name: install-sim
description: Package zoal-charts and install it into the local X-Plane 12 plugins folder for testing. Use when the user wants to try the panel in the sim, or asks to install/deploy locally.
disable-model-invocation: true
---

Package the plugin and install it into the local X-Plane, then tell the user
exactly what to click.

## Steps

1. Validate the manifests first — a bad one installs cleanly and then fails to
   appear in the menu, which is a confusing thing to debug in a cockpit:

   ```sh
   make check
   ```

2. Package and install:

   ```sh
   make install
   ```

   If X-Plane is not at `~/X-Plane 12`, pass its location:

   ```sh
   make install XPLANE_DIR="/path/to/X-Plane 12"
   ```

   `$ARGUMENTS`, if given, is the X-Plane directory.

3. Confirm the installed tree looks right — each platform directory must contain
   both the `.xpl` and its SkyScript library, or the plugin will not load:

   ```sh
   find "$HOME/X-Plane 12/Resources/plugins/zoal-charts" -maxdepth 2 -type f \
     \( -name '*.xpl' -o -name '*SkyScriptLib*' -o -name 'manifest.yaml' \)
   ```

   A local build only covers this platform, so expect one platform directory
   rather than three. That is fine for testing here.

## Then tell the user

- X-Plane must be **restarted** — it reads the plugins folder once at startup.
  Only manifest edits can be picked up live, via
  **Plugins → zoal-charts → Reload configuration**.
- The panel is at **Plugins → zoal-charts → Navigraph Charts**.
- Signing in to Navigraph needs their own subscription.

## Do not

Claim the panel works. You cannot launch X-Plane, so report what you installed
and verified on disk, and leave the in-sim result to the user.
