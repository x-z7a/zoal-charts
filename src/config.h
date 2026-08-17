#ifndef ZOAL_CHARTS_CONFIG_H
#define ZOAL_CHARTS_CONFIG_H

// Branding for the plugin X-Plane loads.
//
// This exists because these values are compiled in, not configurable. Shipping
// SkyScript's stock example binary meant X-Plane called the plugin "SkyScript"
// and signed it com.x-z7a.SkyScript, which is both the wrong name in the
// Plugins menu and a signature collision with every other plugin built from
// that example -- X-Plane loads only one plugin per signature.

#define PRODUCT_NAME "zoal-charts"
#define FRIENDLY_NAME "zoal-charts"
#define PLUGIN_DESCRIPTION "In-sim Navigraph charts panel for X-Plane 12"

// Distinct from com.x-z7a.SkyScript on purpose: this is what stops zoal-charts
// and any other SkyScript-based plugin from being the same plugin to X-Plane.
#define BUNDLE_ID "com.x-z7a.zoal-charts"

#ifndef ZOAL_CHARTS_VERSION
#define ZOAL_CHARTS_VERSION "0.0.0-dev"
#endif

#endif
