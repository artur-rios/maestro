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
# Captured rather than piped into `grep -q`. The early exit `-q` takes on its
# first match closes the pipe under dpkg-deb, and `set -o pipefail` then turns
# that SIGPIPE into a failed smoke test that says nothing about the package.
# The race only started firing once the package grew enough for the match to
# land well before the last byte was written.
deb_contents=$(dpkg-deb --contents "$debian_package")
grep -q './opt/maestro/maestro' <<<"$deb_contents"
grep -q '^preserve-me$' "$work/application-data"
echo 'linux-install-update-smoke: passed'
