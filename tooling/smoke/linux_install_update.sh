#!/usr/bin/env bash
set -euo pipefail

appimage=$(realpath "${1:?AppImage path is required}")
debian_package=$(realpath "${2:?Debian package path is required}")
test -f "$appimage"
test -f "$debian_package"

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
printf 'preserve-me\n' > "$work/application-data"
(
  cd "$work"
  APPIMAGE_EXTRACT_AND_RUN=1 "$appimage" --appimage-extract >/dev/null
  test -x squashfs-root/usr/lib/maestro/maestro
)
dpkg-deb --contents "$debian_package" | grep -q './opt/maestro/maestro'
grep -q '^preserve-me$' "$work/application-data"
echo 'linux-install-update-smoke: passed'
