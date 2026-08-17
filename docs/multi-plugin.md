# Running alongside other SkyScript plugins

Every SkyScript-based plugin ships its own copy of the SkyScript shared library,
and every copy has the same identity. Dynamic loaders key loaded libraries by
that identity rather than by path, so the **second** such plugin X-Plane loads
does not get its own copy — it gets the first one's, and inherits its global
state.

SkyScript keeps real state in globals: `Path` is a singleton holding the plugin
directory, and the app registry, window callbacks and dataref registrations all
live beside it. A plugin that shares another's library therefore scans the wrong
`apps/` directory and adopts the wrong windows.

## What it looks like

zoal-charts installed next to zoal-atc, from X-Plane's `Log.txt`:

```
[zoal-charts] Started (version 0.0.0-dev)
[zoal-charts]: Dataref is not owned by you - you cannot unregister.
[zoal-charts]: XPLMWindowCallbackRecord at 0x... is being deleted by a different plugin.
- 0x... previously created by zoal-atc v0.1.0 (ai.zoal.atc) at 0.00000
[zoal-atc skyscript] Discovered app: zoal-atc (id: app-zoal-atc, default: no)
[zoal-charts] Loaded 1 app(s)
```

The tell is the log prefix: those `[zoal-atc skyscript]` lines are written *during*
zoal-charts' own `skyscript_load_apps_from_directory()` call. The plugin starts
cleanly, reports loading an app, and opens a window belonging to another plugin.
Its own manifest is never read.

## What this repo does about it

`scripts/build-release.sh` renames our copy of the library and rewrites its
identity, so the two are distinct images:

```sh
install_name_tool -id   @rpath/libSkyScriptLib-zoal-charts.dylib  libSkyScriptLib-zoal-charts.dylib
install_name_tool -change @rpath/libSkyScriptLib.dylib @rpath/libSkyScriptLib-zoal-charts.dylib  zoal-charts.xpl
codesign --force --sign - ...
```

The ad-hoc re-signing is not optional: editing a Mach-O invalidates its
signature, and arm64 refuses to load a modified binary whose signature no longer
matches.

**This is macOS only.** The same collision exists on the other two platforms and
is not yet fixed:

- **Linux** keys by `SONAME`, which is `libSkyScriptLib.so` for everyone.
  Fixable the same way with `patchelf --set-soname` on our copy and
  `patchelf --replace-needed` on the `.xpl`.
- **Windows** keys by module base name, so two `SkyScriptLib.dll` in different
  folders collide just as surely. Harder to fix after the fact: the import
  library encodes the DLL name, so renaming means regenerating the import
  library from a `.def` file rather than patching a binary.

## Where the fix really belongs

Upstream. Renaming the library stops plugins from sharing one instance, but each
instance still registers the same *global* X-Plane commands — `skyscript/toggle`
is not namespaced by plugin, so whichever plugin registers it first owns it.
Per-app datarefs are safe, because the app id is derived from the folder name
(`app-charts` and `app-zoal-atc` do not collide).

A proper fix in SkyScript would namespace global commands and datarefs by the
consuming plugin's signature, and stop keeping per-plugin state in singletons.
Until then, the rename is what makes two SkyScript plugins coexist at all.
