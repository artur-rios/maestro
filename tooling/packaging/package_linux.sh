#!/usr/bin/env bash
set -euo pipefail

semantic_version=${1:?semantic version is required}
core_version=${2:?core version is required}
debian_version=${3:?debian version is required}

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
projection_output=$(dart run "$repository/tooling/release/validate_release_projections.dart" "$semantic_version" --core "$core_version" --debian "$debian_version")
if [[ ${MAESTRO_PACKAGING_PREFLIGHT_ONLY:-0} == 1 ]]; then
  printf '%s\n' "$projection_output"
  exit 0
fi
distribution="$repository/dist"
bundle="$repository/build/linux/x64/release/bundle"
appimagetool=${APPIMAGETOOL_PATH:?APPIMAGETOOL_PATH must reference a pinned appimagetool binary}

# The in-application updater composes only when all four release defines are
# stamped into the build. The three published inputs are all-or-nothing: a
# partially configured build would ship an updater that cannot verify what it
# downloads. The package type is the fourth, and it is not an input: each
# package carries its own (see build_bundle).
update_public_key=${MAESTRO_RELEASE_PUBLIC_KEY_BASE64:-}
update_manifest_url=${MAESTRO_RELEASE_MANIFEST_URL:-}
update_signature_url=${MAESTRO_RELEASE_SIGNATURE_URL:-}

defines=("--dart-define=MAESTRO_INSTALLED_VERSION=$semantic_version")
supplied=0
for value in "$update_public_key" "$update_manifest_url" "$update_signature_url"; do
  if [[ -n "$value" ]]; then
    supplied=$((supplied + 1))
  fi
done
updates_configured=0
if [[ $supplied -eq 3 ]]; then
  updates_configured=1
  defines+=("--dart-define=MAESTRO_RELEASE_PUBLIC_KEY_BASE64=$update_public_key")
  defines+=("--dart-define=MAESTRO_RELEASE_MANIFEST_URL=$update_manifest_url")
  defines+=("--dart-define=MAESTRO_RELEASE_SIGNATURE_URL=$update_signature_url")
  echo 'runtime-updates: configured'
elif [[ $supplied -ne 0 ]]; then
  echo 'Runtime update configuration is incomplete: supply the public key, manifest URL, and signature URL together, or none of them.' >&2
  exit 1
else
  echo 'runtime-updates: unconfigured'
fi

# The package type tells the updater which release artifact to fetch and how to
# install it: an AppImage replaces its own .AppImage file, while a Debian
# install hands the new .deb to the system package manager. It is compiled in,
# so a build configured for updates is made once per package. Without updates
# the bundles would be identical, and one build serves both packages.
build_bundle() {
  local package_type=$1
  local package_define=()
  if [[ $updates_configured -eq 1 ]]; then
    package_define=("--dart-define=MAESTRO_RELEASE_PACKAGE_TYPE=$package_type")
    echo "runtime-update-package-type: $package_type"
  fi
  flutter build linux --release --build-name "$core_version" "${defines[@]}" "${package_define[@]}"
  test -x "$bundle/maestro"
}

mkdir -p "$distribution"

appdir=$(mktemp -d)
debian_root=$(mktemp -d)
trap 'rm -rf -- "$appdir" "$debian_root"' EXIT

build_bundle appimage
mkdir -p "$appdir/usr/lib/maestro"
cp -a -- "$bundle/." "$appdir/usr/lib/maestro/"
cp -- "$repository/tooling/updates/replace_linux_appimage.sh" "$appdir/usr/lib/maestro/replace_linux_appimage.sh"
chmod 0755 "$appdir/usr/lib/maestro/replace_linux_appimage.sh"
cp -- "$repository/tooling/packaging/maestro.desktop" "$appdir/maestro.desktop"
cp -- "$repository/tooling/packaging/maestro.svg" "$appdir/maestro.svg"
# appimagetool reads the icon named by the desktop entry from the AppDir root;
# the hicolor tree is what a desktop shows once the AppImage is integrated.
mkdir -p "$appdir/usr/share/icons/hicolor/scalable/apps"
cp -- "$repository/tooling/packaging/maestro.svg" "$appdir/usr/share/icons/hicolor/scalable/apps/maestro.svg"
for size in 16 24 32 48 64 128 256 512; do
  mkdir -p "$appdir/usr/share/icons/hicolor/${size}x${size}/apps"
  cp -- "$repository/tooling/packaging/icons/maestro-$size.png" "$appdir/usr/share/icons/hicolor/${size}x${size}/apps/maestro.png"
done
ln -s usr/lib/maestro/maestro "$appdir/AppRun"
ARCH=x86_64 VERSION="$semantic_version" "$appimagetool" "$appdir" "$distribution/maestro-linux-x64.AppImage"

if [[ $updates_configured -eq 1 ]]; then
  build_bundle deb
fi
mkdir -p "$debian_root/DEBIAN" "$debian_root/opt/maestro" "$debian_root/usr/bin" "$debian_root/usr/share/applications" "$debian_root/usr/share/icons/hicolor/scalable/apps"
cp -a -- "$bundle/." "$debian_root/opt/maestro/"
ln -s /opt/maestro/maestro "$debian_root/usr/bin/maestro"
cp -- "$repository/tooling/packaging/maestro.desktop" "$debian_root/usr/share/applications/maestro.desktop"
cp -- "$repository/tooling/packaging/maestro.svg" "$debian_root/usr/share/icons/hicolor/scalable/apps/maestro.svg"
# Raster sizes alongside the scalable one, for the environments and panels that
# never rasterise SVG themselves.
for size in 16 24 32 48 64 128 256 512; do
  mkdir -p "$debian_root/usr/share/icons/hicolor/${size}x${size}/apps"
  cp -- "$repository/tooling/packaging/icons/maestro-$size.png" "$debian_root/usr/share/icons/hicolor/${size}x${size}/apps/maestro.png"
done
sed "s/@VERSION@/$debian_version/g" "$repository/tooling/packaging/debian/control" > "$debian_root/DEBIAN/control"
dpkg-deb --root-owner-group --build "$debian_root" "$distribution/maestro-linux-amd64.deb"

echo "Created $distribution/maestro-linux-x64.AppImage"
echo "Created $distribution/maestro-linux-amd64.deb"
