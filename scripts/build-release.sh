#!/usr/bin/env bash
set -euo pipefail

# Assemble the drop-in X-Plane plugin folder.
#
# Inputs are the .xpl files built by CMake into build-plugin/<platform>/ and the
# SkyScript bundle provisioned by scripts/ensure-deps.sh. One platform can only
# be built on itself, so a local run packages whatever is present and says what
# is missing; CI collects all three before calling this.
#
# CEF is deliberately absent. Since SkyScript v0.5.0 the library resolves the
# Chromium runtime X-Plane already ships (on macOS the .xpl references
# @executable_path/../Frameworks/Chromium Embedded Framework.framework), so
# bundling one would add ~200MB that would not even be the copy that loads.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_build_dir="${ZOAL_CHARTS_PLUGIN_BUILD_DIR:-${repo_root}/build-plugin}"
skyscript_root="${ZOAL_CHARTS_SKYSCRIPT_ROOT:-${repo_root}/.cache/skyscript/SkyScript-lib}"
dist_dir="${ZOAL_CHARTS_DIST_DIR:-${repo_root}/dist}"
release_dir="${dist_dir}/zoal-charts"
pin_file="${repo_root}/scripts/skyscript-version.txt"

# A release must carry all three platforms; a local build normally cannot. This
# is what stops a mac-only tree from being published as if it were complete.
require_all="${ZOAL_CHARTS_REQUIRE_ALL_PLATFORMS:-0}"

if [ ! -d "${skyscript_root}" ]; then
  echo "SkyScript bundle not found at ${skyscript_root}." >&2
  echo "Run scripts/ensure-deps.sh first." >&2
  exit 1
fi

if [ ! -d "${skyscript_root}/assets" ]; then
  echo "SkyScript assets not found at ${skyscript_root}/assets." >&2
  echo "Re-run scripts/ensure-deps.sh: a release without them has no back button." >&2
  exit 1
fi

version="$(tr -d '[:space:]' < "${pin_file}")"

rm -rf "${release_dir}"
mkdir -p "${release_dir}/assets" "${release_dir}/apps" "${release_dir}/licenses/skyscript"

packaged=0
missing=()

for platform in mac_x64 win_x64 lin_x64; do
  case "${platform}" in
    mac_x64) library_name="libSkyScriptLib.dylib" ;;
    lin_x64) library_name="libSkyScriptLib.so" ;;
    win_x64) library_name="SkyScriptLib.dll" ;;
  esac

  xpl_source="${plugin_build_dir}/${platform}/zoal-charts.xpl"
  if [ ! -f "${xpl_source}" ]; then
    missing+=("${platform}")
    continue
  fi

  library_source="${skyscript_root}/lib/${platform}/${library_name}"
  if [ ! -f "${library_source}" ]; then
    echo "Missing SkyScript library for ${platform}: ${library_source}" >&2
    exit 1
  fi

  # The library sits *beside* the .xpl, not under lib/. The macOS binary's only
  # rpath is @loader_path, so a dylib left in lib/mac_x64 is one the plugin
  # cannot find, and X-Plane reports a plugin that failed to load.
  mkdir -p "${release_dir}/${platform}"
  cp "${xpl_source}" "${release_dir}/${platform}/zoal-charts.xpl"
  cp "${library_source}" "${release_dir}/${platform}/${library_name}"
  packaged=$((packaged + 1))
done

if [ "${packaged}" -eq 0 ]; then
  echo "No plugin binaries found under ${plugin_build_dir}." >&2
  echo "Run 'make plugin' first." >&2
  exit 1
fi

if [ "${#missing[@]}" -gt 0 ]; then
  if [ "${require_all}" = "1" ]; then
    echo "Refusing to package a release missing: ${missing[*]}" >&2
    echo "Each platform must be built on itself; CI does all three." >&2
    exit 1
  fi
  echo "warning: packaging without ${missing[*]} (built on this machine only)" >&2
fi

cp -R "${skyscript_root}/assets/." "${release_dir}/assets/"
cp -R "${repo_root}/apps/." "${release_dir}/apps/"

if [ -f "${skyscript_root}/LICENSE" ]; then
  cp "${skyscript_root}/LICENSE" "${release_dir}/licenses/skyscript/LICENSE"
fi

# Record which SkyScript this was built against, so a bug report can name it
# instead of guessing from a file date.
printf '%s\n' "${version}" > "${release_dir}/licenses/skyscript/SKYSCRIPT_VERSION"

echo "Packaged ${release_dir} (${packaged}/3 platforms) against SkyScript ${version}"
