// The zoal-charts X-Plane plugin.
//
// Adapted from SkyScript's example plugin (MIT, x-z7a/SkyScript), which this
// replaces. We build our own binary rather than shipping that one for a single
// reason: the plugin name and signature are compiled in, so the stock example
// makes X-Plane call this plugin "SkyScript" and collide with every other
// plugin built from it.
//
// The logic is deliberately still the example's: register with X-Plane, hand
// SkyScript the apps/ directory, and put what it finds in the Plugins menu.
// Everything that draws, browses or renders lives in the SkyScript library
// behind skyscript_c.h -- a stable C ABI, so this file needs no C++ coupling
// to it and can be built with any toolchain.
//
// The upstream example's libcurl version check is dropped: it fetched the
// GitHub releases API, ignored the response, and assigned VERSION to itself.
// Removing it also removes libcurl from the link line.

#ifndef XPLM301
    #error This project requires the X-Plane SDK 4.x for X-Plane 12
#endif

#include "config.h"

#include "skyscript_c.h"

#include <cstdarg>
#include <cstdio>
#include <cstring>

#include <XPLMDisplay.h>
#include <XPLMMenus.h>
#include <XPLMPlugin.h>
#include <XPLMUtilities.h>

#if IBM
#include <windows.h>
BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID reserved) {
    (void)module;
    (void)reason;
    (void)reserved;
    return TRUE;
}
#endif

namespace {

XPLMMenuID g_plugin_menu = nullptr;
int g_apps_menu_first_item = 0;
bool g_apps_loaded = false;

// X-Plane's own log. Prefixed so a line in Log.txt names the plugin that wrote
// it rather than leaving the reader to guess between plugins.
void plugin_log(const char *format, ...) {
    char message[1024];
    int prefix_length = snprintf(message, sizeof(message), "[" FRIENDLY_NAME "] ");
    if (prefix_length < 0 || static_cast<size_t>(prefix_length) >= sizeof(message)) {
        return;
    }

    va_list args;
    va_start(args, format);
    vsnprintf(message + prefix_length, sizeof(message) - static_cast<size_t>(prefix_length),
              format, args);
    va_end(args);

    XPLMDebugString(message);
}

// XPluginStart hands us three fixed 256-byte buffers. snprintf rather than
// strcpy so a longer name than expected truncates instead of overrunning them.
void copy_to_plugin_buffer(char *destination, const char *value) {
    snprintf(destination, 256, "%s", value);
}

void rebuild_apps_menu();

void menu_handler(void *menu_ref, void *item_ref) {
    (void)menu_ref;

    if (item_ref == nullptr) {
        return;
    }

    if (std::strcmp(static_cast<char *>(item_ref), "reload") == 0) {
        skyscript_reload_apps();
        rebuild_apps_menu();
        plugin_log("Reloaded apps from disk\n");
        return;
    }

    // Any other item is an app handle stashed in the menu item itself.
    SkyScriptApp app = static_cast<SkyScriptApp>(item_ref);
    if (skyscript_app_is_visible(app)) {
        skyscript_app_hide(app);
    } else {
        skyscript_app_show(app, nullptr);
        skyscript_set_active_app(app);
    }
}

// Each discovered app becomes one menu item, above a separator and the reload
// item. The apps are rebuilt on reload, so the whole menu is rebuilt with them
// rather than trying to patch entries in place.
void rebuild_apps_menu() {
    if (g_plugin_menu == nullptr) {
        return;
    }

    XPLMClearAllMenuItems(g_plugin_menu);
    g_apps_menu_first_item = 0;

    int count = skyscript_get_app_window_count();
    for (int index = 0; index < count; index++) {
        SkyScriptApp app = skyscript_get_app_window_at(index);
        if (app == nullptr) {
            continue;
        }
        XPLMAppendMenuItem(g_plugin_menu, skyscript_app_get_name(app), app, 0);
    }

    if (count == 0) {
        // Better than an empty menu: an install missing apps/ is otherwise
        // indistinguishable from a plugin that failed to load.
        XPLMAppendMenuItem(g_plugin_menu, "No charts app found in apps/", nullptr, 0);
    }

    XPLMAppendMenuSeparator(g_plugin_menu);
    XPLMAppendMenuItem(g_plugin_menu, "Reload configuration", (void *)"reload", 0);
}

} // namespace

PLUGIN_API int XPluginStart(char *name, char *signature, char *description) {
    copy_to_plugin_buffer(name, FRIENDLY_NAME);
    copy_to_plugin_buffer(signature, BUNDLE_ID);
    copy_to_plugin_buffer(description, PLUGIN_DESCRIPTION);

    // Native paths give us UTF-8 POSIX paths instead of legacy HFS ones. It has
    // to be set before SkyScript resolves the plugin directory, or app
    // discovery looks in a path that does not exist.
    XPLMEnableFeature("XPLM_USE_NATIVE_PATHS", 1);
    XPLMEnableFeature("XPLM_USE_NATIVE_WIDGET_WINDOWS", 1);

    skyscript_initialize();

    int menu_item = XPLMAppendMenuItem(XPLMFindPluginsMenu(), FRIENDLY_NAME, nullptr, 1);
    g_plugin_menu = XPLMCreateMenu(FRIENDLY_NAME, XPLMFindPluginsMenu(), menu_item,
                                   menu_handler, nullptr);

    plugin_log("Started (version %s)\n", ZOAL_CHARTS_VERSION);
    return 1;
}

PLUGIN_API void XPluginStop(void) {
    skyscript_shutdown();
    g_plugin_menu = nullptr;
    g_apps_loaded = false;
    plugin_log("Stopped\n");
}

PLUGIN_API int XPluginEnable(void) {
    return 1;
}

PLUGIN_API void XPluginDisable(void) {
}

PLUGIN_API void XPluginReceiveMessage(XPLMPluginID from, long message, void *param) {
    (void)from;

    switch (message) {
        case XPLM_MSG_PLANE_LOADED:
            // Only the user's aircraft (index 0) matters. AI aircraft loading
            // would otherwise rescan apps/ repeatedly for no reason.
            if (reinterpret_cast<intptr_t>(param) != 0) {
                return;
            }

            // Apps are discovered once. SkyScript needs a loaded aircraft
            // before it can create windows, which is why this is not in
            // XPluginStart.
            if (!g_apps_loaded && skyscript_load_apps_from_directory()) {
                rebuild_apps_menu();
                g_apps_loaded = true;
                plugin_log("Loaded %d app(s)\n", skyscript_get_app_window_count());
            }
            break;

        case XPLM_MSG_PLANE_UNLOADED:
            if (reinterpret_cast<intptr_t>(param) != 0) {
                return;
            }

            if (g_plugin_menu != nullptr) {
                XPLMClearAllMenuItems(g_plugin_menu);
            }
            skyscript_destroy_all_app_windows();
            g_apps_loaded = false;
            break;

        default:
            break;
    }
}
