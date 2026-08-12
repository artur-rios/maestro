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

flutter build linux --release --build-name "$core_version" --dart-define="MAESTRO_INSTALLED_VERSION=$semantic_version"
test -x "$bundle/maestro"
cp -- "$repository/tooling/updates/replace_linux_appimage.sh" "$bundle/replace_linux_appimage.sh"
chmod 0755 "$bundle/replace_linux_appimage.sh"
mkdir -p "$distribution"

appdir=$(mktemp -d)
debian_root=$(mktemp -d)
trap 'rm -rf -- "$appdir" "$debian_root"' EXIT

mkdir -p "$appdir/usr/lib/maestro"
cp -a -- "$bundle/." "$appdir/usr/lib/maestro/"
cp -- "$repository/tooling/packaging/maestro.desktop" "$appdir/maestro.desktop"
cp -- "$repository/tooling/packaging/maestro.svg" "$appdir/maestro.svg"
ln -s usr/lib/maestro/maestro "$appdir/AppRun"
ARCH=x86_64 VERSION="$semantic_version" "$appimagetool" "$appdir" "$distribution/maestro-linux-x64.AppImage"

mkdir -p "$debian_root/DEBIAN" "$debian_root/opt/maestro" "$debian_root/usr/bin" "$debian_root/usr/share/applications" "$debian_root/usr/share/icons/hicolor/scalable/apps"
cp -a -- "$bundle/." "$debian_root/opt/maestro/"
ln -s /opt/maestro/maestro "$debian_root/usr/bin/maestro"
cp -- "$repository/tooling/packaging/maestro.desktop" "$debian_root/usr/share/applications/maestro.desktop"
cp -- "$repository/tooling/packaging/maestro.svg" "$debian_root/usr/share/icons/hicolor/scalable/apps/maestro.svg"
sed "s/@VERSION@/$debian_version/g" "$repository/tooling/packaging/debian/control" > "$debian_root/DEBIAN/control"
dpkg-deb --root-owner-group --build "$debian_root" "$distribution/maestro-linux-amd64.deb"

echo "Created $distribution/maestro-linux-x64.AppImage"
echo "Created $distribution/maestro-linux-amd64.deb"
