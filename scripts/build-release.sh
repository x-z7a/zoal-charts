#!/usr/bin/env bash
set -euo pipefail

# Assemble the drop-in X-Plane plugin folder from a pinned SkyScript release.
#
# This repo compiles nothing. SkyScript's *example* release already ships a
# built .xpl for all three platforms whose entire job is to scan apps/ and put
# each app in the Plugins menu -- which is exactly the plugin we want. So a
# release here is that binary plus our manifest, and the build is a download and
# a copy.
#
# CEF is deliberately absent. Since SkyScript v0.5.0 the library resolves the
# CEF runtime X-Plane already ships (on macOS the .xpl references
# @executable_path/../Frameworks/Chromium Embedded Framework.framework), so
# bundling one would add ~200MB that would not even be the copy that loads.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pin_file="${repo_root}/scripts/skyscript-version.txt"
cache_dir="${repo_root}/.cache/skyscript"
dist_dir="${ZOAL_CHARTS_DIST_DIR:-${repo_root}/dist}"
release_dir="${dist_dir}/zoal-charts"
repo="${ZOAL_CHARTS_SKYSCRIPT_REPO:-x-z7a/SkyScript}"

if [ ! -f "${pin_file}" ]; then
  echo "Missing SkyScript version pin: ${pin_file}" >&2
  exit 1
fi

# The pin is the one place to edit to take a new SkyScript. Overriding the
# variable tries a version without moving the pin, which is what you want when
# checking whether an upstream fix landed.
version="${ZOAL_CHARTS_SKYSCRIPT_VERSION:-$(tr -d '[:space:]' < "${pin_file}")}"
if [ -z "${version}" ]; then
  echo "SkyScript version pin is empty: ${pin_file}" >&2
  exit 1
fi

numeric_version="${version#v}"
asset="SkyScript-example-${numeric_version}-XP12.zip"
archive="${cache_dir}/${asset}"
extract_root="${cache_dir}/${version}"
skyscript_root="${extract_root}/SkyScript-example"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required to download the pinned SkyScript release." >&2
  echo "Install it (brew install gh) or unzip ${asset} into ${extract_root} yourself." >&2
  exit 1
fi

# Cache by version. The example archive is ~140MB, and re-downloading it on
# every package run for a pin that has not moved is the slowest possible way to
# get the same bytes.
if [ ! -f "${archive}" ]; then
  echo "Downloading SkyScript ${version} (${asset})..."
  mkdir -p "${cache_dir}"
  gh release download "${version}" --repo "${repo}" --pattern "${asset}" --dir "${cache_dir}"
fi

# Extract only what ships. The archive also carries example/ -- the plugin's own
# source and build tree -- which is 669MB of the 682MB unpacked and none of it
# ends up in a release.
if [ ! -d "${skyscript_root}" ]; then
  echo "Extracting ${asset}..."
  mkdir -p "${extract_root}"
  unzip -q -o "${archive}" -d "${extract_root}" \
    'SkyScript-example/mac_x64/*' \
    'SkyScript-example/win_x64/*' \
    'SkyScript-example/lin_x64/*' \
    'SkyScript-example/lib/*' \
    'SkyScript-example/assets/*'
fi

if [ ! -d "${skyscript_root}" ]; then
  echo "Expected ${skyscript_root} inside ${asset}, but it is not there." >&2
  echo "The release layout changed; update this script rather than working around it." >&2
  exit 1
fi

rm -rf "${release_dir}"
mkdir -p "${release_dir}/assets" "${release_dir}/apps" "${release_dir}/licenses/skyscript"

# The library sits *beside* the .xpl, not under lib/. The macOS binary's only
# rpath is @loader_path, so a dylib left in lib/mac_x64 is a dylib the plugin
# cannot find, and X-Plane reports it as a plugin that failed to load.
for platform in mac_x64 win_x64 lin_x64; do
  case "${platform}" in
    mac_x64) library_name="libSkyScriptLib.dylib" ;;
    lin_x64) library_name="libSkyScriptLib.so" ;;
    win_x64) library_name="SkyScriptLib.dll" ;;
  esac

  xpl_source="${skyscript_root}/${platform}/SkyScript.xpl"
  library_source="${skyscript_root}/lib/${platform}/${library_name}"

  if [ ! -f "${xpl_source}" ]; then
    echo "Missing plugin binary: ${xpl_source}" >&2
    exit 1
  fi
  if [ ! -f "${library_source}" ]; then
    echo "Missing SkyScript library: ${library_source}" >&2
    exit 1
  fi

  mkdir -p "${release_dir}/${platform}"
  cp "${xpl_source}" "${release_dir}/${platform}/SkyScript.xpl"
  cp "${library_source}" "${release_dir}/${platform}/${library_name}"
done

cp -R "${skyscript_root}/assets/." "${release_dir}/assets/"

# Only our app ships. The example bundle also carries hello-world, web-browser,
# about and simbrief; leaving them in would put four apps a charts plugin never
# promised into the pilot's Plugins menu.
cp -R "${repo_root}/apps/." "${release_dir}/apps/"

# We redistribute SkyScript's binaries, so its MIT licence ships with them. The
# example archive does not carry one, so it comes from the repo at the pinned
# tag -- the same commit the binaries were built from.
license_dest="${release_dir}/licenses/skyscript/LICENSE"
if ! gh api "repos/${repo}/contents/LICENSE?ref=${version}" \
    --jq '.content' 2>/dev/null | base64 -d > "${license_dest}"; then
  rm -f "${license_dest}"
  echo "warning: could not fetch SkyScript's LICENSE for ${version};" >&2
  echo "         add it before publishing a release." >&2
fi

# Record which SkyScript this was built against, so a bug report can name it
# instead of guessing from a file date.
printf '%s\n' "${version}" > "${release_dir}/licenses/skyscript/SKYSCRIPT_VERSION"

echo "Packaged ${release_dir} against SkyScript ${version}"
