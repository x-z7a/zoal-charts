#!/usr/bin/env bash
set -euo pipefail

# Provision what building the plugin needs: the X-Plane SDK, and the SkyScript
# library bundle plus its runtime assets.
#
# Both come from pinned versions rather than "latest", so a build is
# reproducible and the version moves when someone decides it should. The
# SkyScript pin lives in scripts/skyscript-version.txt.
#
# Three downloads, ~10MB total, and deliberately not the SkyScript *example*
# release: that archive is 140MB because it carries the plugin's own source and
# build tree, and now that we build our own .xpl we need none of it.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cache_dir="${repo_root}/.cache"
sdk_root="${cache_dir}/sdk"
skyscript_root="${cache_dir}/skyscript/SkyScript-lib"
pin_file="${repo_root}/scripts/skyscript-version.txt"
repo="${ZOAL_CHARTS_SKYSCRIPT_REPO:-x-z7a/SkyScript}"
sdk_version="${ZOAL_CHARTS_SDK_VERSION:-410}"

if [ ! -f "${pin_file}" ]; then
  echo "Missing SkyScript version pin: ${pin_file}" >&2
  exit 1
fi

version="${ZOAL_CHARTS_SKYSCRIPT_VERSION:-$(tr -d '[:space:]' < "${pin_file}")}"
if [ -z "${version}" ]; then
  echo "SkyScript version pin is empty: ${pin_file}" >&2
  exit 1
fi

mkdir -p "${cache_dir}"

# ---------------------------------------------------------------- X-Plane SDK

# A local SDK checkout is worth reusing: it saves a download, and it is the same
# SDK. ZOAL_CHARTS_SDK_ROOT points at one explicitly.
if [ -n "${ZOAL_CHARTS_SDK_ROOT:-}" ]; then
  if [ ! -f "${ZOAL_CHARTS_SDK_ROOT}/CHeaders/XPLM/XPLMPlugin.h" ]; then
    echo "ZOAL_CHARTS_SDK_ROOT does not look like an X-Plane SDK: ${ZOAL_CHARTS_SDK_ROOT}" >&2
    exit 1
  fi
  rm -rf "${sdk_root}"
  mkdir -p "$(dirname "${sdk_root}")"
  cp -R "${ZOAL_CHARTS_SDK_ROOT}" "${sdk_root}"
  echo "Using X-Plane SDK from ${ZOAL_CHARTS_SDK_ROOT}"
elif [ ! -f "${sdk_root}/CHeaders/XPLM/XPLMPlugin.h" ]; then
  sdk_zip="${cache_dir}/XPSDK${sdk_version}.zip"
  if [ ! -f "${sdk_zip}" ]; then
    echo "Downloading X-Plane SDK ${sdk_version}..."
    curl -fsSL -o "${sdk_zip}" \
      "https://developer.x-plane.com/wp-content/plugins/code-sample-generation/sdk_zip_files/XPSDK${sdk_version}.zip"
  fi
  echo "Extracting X-Plane SDK..."
  rm -rf "${sdk_root}" "${cache_dir}/SDK"
  unzip -q -o "${sdk_zip}" -d "${cache_dir}"
  mv "${cache_dir}/SDK" "${sdk_root}"
fi

# ---------------------------------------------------------- SkyScript library

skyscript_stamp="${skyscript_root}/SKYSCRIPT_VERSION"

# The stamp is what makes bumping the pin take effect. Checking only that the
# files exist would leave an older cached bundle in place forever, and the build
# would keep linking a version nobody asked for.
if [ ! -f "${skyscript_stamp}" ] || [ "$(cat "${skyscript_stamp}")" != "${version}" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh is required to download SkyScript ${version} (brew install gh)." >&2
    exit 1
  fi

  numeric_version="${version#v}"
  lib_asset="SkyScript-lib-${numeric_version}-XP12.zip"
  lib_zip="${cache_dir}/${lib_asset}"

  if [ ! -f "${lib_zip}" ]; then
    echo "Downloading SkyScript ${version} library bundle..."
    gh release download "${version}" --repo "${repo}" --pattern "${lib_asset}" --dir "${cache_dir}"
  fi

  echo "Extracting SkyScript library bundle..."
  rm -rf "${skyscript_root}"
  mkdir -p "${cache_dir}/skyscript"
  unzip -q -o "${lib_zip}" -d "${cache_dir}/skyscript"

  # The library bundle ships no assets, but SkyScript loads icons and its
  # notification sound from <plugin>/assets at runtime -- a release without them
  # is a plugin with no back button. They come from the source tarball at the
  # same tag: 828KB, against 140MB for the example release that also has them.
  assets_tarball="${cache_dir}/SkyScript-${numeric_version}-src.tar.gz"
  if [ ! -f "${assets_tarball}" ]; then
    echo "Downloading SkyScript ${version} assets..."
    curl -fsSL -o "${assets_tarball}" \
      "https://github.com/${repo}/archive/refs/tags/${version}.tar.gz"
  fi

  tar -xzf "${assets_tarball}" -C "${cache_dir}/skyscript" \
    --strip-components=1 "SkyScript-${numeric_version}/assets"
  rm -rf "${skyscript_root}/assets"
  mv "${cache_dir}/skyscript/assets" "${skyscript_root}/assets"

  printf '%s\n' "${version}" > "${skyscript_stamp}"
fi

echo "Dependencies ready:"
echo "  X-Plane SDK   ${sdk_root}"
echo "  SkyScript     ${skyscript_root} (${version})"
