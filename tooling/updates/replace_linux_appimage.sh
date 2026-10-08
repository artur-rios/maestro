#!/usr/bin/env bash
set -euo pipefail

# The caller must supply all three: package, install path, and the parent
# process id to wait on. Failing loudly here is what keeps an installer that
# forgot one from looking like a working update.
if [[ $# -ne 3 ]]; then
  echo "usage: replace_linux_appimage.sh <package_path> <install_path> <parent_pid>" >&2
  exit 64
fi

# package_path is the verified download, staged with ordinary file permissions.
# install_path is the .AppImage file itself, as the AppImage runtime names it in
# $APPIMAGE -- not the executable inside its read-only mount.
package_path="$1"
install_path="$2"
# parent-pid is supplied by the running app so replacement begins only after exit.
parent_pid="$3"

[[ "$package_path" = /* && "$install_path" = /* ]] || { echo 'Update paths must be absolute.' >&2; exit 64; }
[[ -f "$package_path" && -r "$package_path" ]] || { echo 'Verified AppImage is unavailable.' >&2; exit 66; }
[[ -f "$install_path" ]] || { echo 'Installed AppImage is unavailable.' >&2; exit 66; }
while kill -0 "$parent_pid" 2>/dev/null; do sleep 0.25; done

# Staged beside the installed file, so it is on the same filesystem and the
# final rename replaces the installed AppImage in one step: whoever opens it
# sees the old file or the new one, never a missing or partly written one. Any
# failure before that rename leaves the installed AppImage as it was.
staging="${install_path}.staging"
rm -f -- "$staging"
trap 'rm -f -- "$staging"' EXIT
cp -- "$package_path" "$staging"
# Keep the installed file's permissions, and make sure it stays executable.
chmod --reference="$install_path" -- "$staging"
chmod u+x -- "$staging"
sync -- "$staging"
mv -f -- "$staging" "$install_path"
trap - EXIT
exec "$install_path"
