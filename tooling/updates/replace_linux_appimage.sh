#!/usr/bin/env bash
set -euo pipefail

# The caller must supply all three: package, install path, and the parent
# process id to wait on. Failing loudly here is what keeps an installer that
# forgot one from looking like a working update.
if [[ $# -ne 3 ]]; then
  echo "usage: replace_linux_appimage.sh <package_path> <install_path> <parent_pid>" >&2
  exit 64
fi

package_path="$1"
install_path="$2"
# parent-pid is supplied by the running app so replacement begins only after exit.
parent_pid="$3"

[[ "$package_path" = /* && "$install_path" = /* ]] || { echo 'Update paths must be absolute.' >&2; exit 64; }
[[ -f "$package_path" && -x "$package_path" ]] || { echo 'Verified AppImage is unavailable.' >&2; exit 66; }
while kill -0 "$parent_pid" 2>/dev/null; do sleep 0.25; done

rollback="${install_path}.rollback"
staging="${install_path}.staging"
rm -f -- "$staging" "$rollback"
trap 'rm -f -- "$staging"' EXIT
cp -- "$package_path" "$staging"
chmod 0755 "$staging"
if mv -- "$install_path" "$rollback" && mv -- "$staging" "$install_path"; then
  rm -f -- "$rollback"
  exec "$install_path"
fi
if [[ ! -e "$install_path" && -e "$rollback" ]]; then mv -- "$rollback" "$install_path"; fi
exit 1
