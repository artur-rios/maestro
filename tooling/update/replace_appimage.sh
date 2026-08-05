#!/usr/bin/env bash
set -euo pipefail

staged_path=${1:?staged AppImage path is required}
install_path=${2:?installed AppImage path is required}

if [[ ! -f "$staged_path" ]]; then
  echo "staged AppImage does not exist" >&2
  exit 1
fi
if [[ "$install_path" != /* || "$install_path" == "/" ]]; then
  echo "install path must be an absolute file path" >&2
  exit 1
fi

install_directory=$(dirname -- "$install_path")
temporary_path="$install_directory/.maestro-update-$$"
trap 'rm -f -- "$temporary_path"' EXIT
cp -- "$staged_path" "$temporary_path"
chmod 0755 "$temporary_path"
mv -f -- "$temporary_path" "$install_path"
