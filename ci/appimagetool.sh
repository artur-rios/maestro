# shellcheck shell=bash
# Sourced by the scripts under ci/ that package the AppImage (not run on its own).
#
#     ensure_appimagetool
#
# Downloads the pinned appimagetool (the workflows' "Install pinned appimagetool" step), checks its SHA-256 and
# exports APPIMAGETOOL_PATH for tooling/packaging/package_linux.sh. APPIMAGE_EXTRACT_AND_RUN lets the AppImages
# (appimagetool itself, and the package it makes) run without FUSE, which a container does not have.
#
# Change APPIMAGETOOL_SHA256 together with the version (Renovate bumps the version, not the checksum), and the
# same two values in docs/development/releases-and-signing.md.

# renovate: datasource=github-releases depName=AppImage/appimagetool
APPIMAGETOOL_VERSION=1.9.1
APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0

ensure_appimagetool() {
  local directory
  directory=$(mktemp -d)
  curl --fail --silent --show-error --location --retry 3 --output "$directory/appimagetool" \
    "https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage"
  echo "$APPIMAGETOOL_SHA256  $directory/appimagetool" | sha256sum --check --strict -
  chmod 0755 "$directory/appimagetool"
  export APPIMAGE_EXTRACT_AND_RUN=1
  export APPIMAGETOOL_PATH="$directory/appimagetool"
}
