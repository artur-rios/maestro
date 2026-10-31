#!/usr/bin/env bash
# The release's Linux files (`release.build` in yggdrasil.yml), run on the release agent from the checkout of the
# release's tag. It ports the ubuntu jobs of the old release.yml:
#
#   validate-release  the tag is one the release tooling accepts, and the version projections come from it
#                     (the old job also checked the tagged commit is on main: the pipeline checks that now);
#   verify            the analyze-test gate (ci/analyze-test.sh, the old verify.yml);
#   linux-package     the AppImage and the Debian package for the version (tooling/packaging/package_linux.sh),
#                     with the updater's public key stamped in.
#
# The files land in dist/ (the release's `files`). The Windows packages are the release-windows.yml workflow's;
# release.validate checks the whole set, and yggdrasil's pipeline uploads and publishes it on the git server and
# on the GitHub mirror.
#
# The signed update manifest (create_manifest.dart, sign_manifest.dart, verify_release.dart: the old `release` job)
# is not made here: it covers the Windows ZIP and MSIX too, which reach the pipeline after this script has run. It is
# release.finalize's (ci/release-finalize.sh).
#
# RELEASE_TAG (the tag, vX.Y.Z or a pre-release) and RELEASE_VERSION are set by the pipeline; by hand, set
# RELEASE_TAG. MAESTRO_RELEASE_PUBLIC_KEY_BASE64 is the credential `maestro-signing-public-key`; without it the
# updater cannot be stamped in and package_linux.sh stops, rather than ship a build that cannot update.
#
# It installs the Linux desktop prerequisites with apt, so it runs as root, as release builds do on the release
# agent (ci/apt-packages.sh).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

tag=${RELEASE_TAG:?ci/release-build.sh: RELEASE_TAG (the release tag) is not set}
: "${MAESTRO_RELEASE_PUBLIC_KEY_BASE64:?ci/release-build.sh: MAESTRO_RELEASE_PUBLIC_KEY_BASE64 (the credential maestro-signing-public-key) is not set}"
# The addresses a running Maestro checks for updates. GitHub had them as the repository variables of the same names,
# which Jenkins cannot read: the release's GitHub copy is where the manifest is published, so they are the stable
# "latest release" addresses (docs/development/releases-and-signing.md). The Windows workflow still reads the
# repository variables: keep them equal.
export MAESTRO_RELEASE_MANIFEST_URL=${MAESTRO_RELEASE_MANIFEST_URL:-https://github.com/artur-rios/maestro/releases/latest/download/release-manifest.json}
export MAESTRO_RELEASE_SIGNATURE_URL=${MAESTRO_RELEASE_SIGNATURE_URL:-https://github.com/artur-rios/maestro/releases/latest/download/release-manifest.sig}

# shellcheck source=ci/apt-packages.sh
source ci/apt-packages.sh
ensure_packages clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libsqlite3-dev libjsoncpp-dev \
  libayatana-appindicator3-dev file
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh
# shellcheck source=ci/appimagetool.sh
source ci/appimagetool.sh

# ---- validate-release: the tag, and the versions projected from it ----
flutter pub get
versions=$(mktemp)
dart tooling/release/validate_release_tag.dart "$tag" "$versions"
semantic_version=$(sed -n 's/^semantic_version=//p' "$versions")
core_version=$(sed -n 's/^core_version=//p' "$versions")
debian_version=$(sed -n 's/^debian_version=//p' "$versions")
rm -f "$versions"
echo "release $tag: semantic $semantic_version, core $core_version, debian $debian_version"

# ---- verify: the same gate CI runs, so a tag never publishes a commit nothing verified ----
bash ci/analyze-test.sh

# ---- linux-package ----
ensure_appimagetool
rm -rf dist
bash tooling/packaging/package_linux.sh "$semantic_version" "$core_version" "$debian_version"
