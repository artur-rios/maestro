#!/usr/bin/env bash
# The release's update manifest (`release.finalize` in yggdrasil.yml), run on the release agent after the files are
# built, gathered and validated. It ports the old release.yml's `release` job step "Create and optionally sign
# release manifest": the manifest (release-manifest.json), the checksum list (SHA256SUMS) and the manifest's
# detached Ed25519 signature (release-manifest.sig) over the whole set, Windows packages included, then the
# verification of all of it (verify_release.dart), which also needs exactly the five packages.
#
# The pipeline puts the release's files under RELEASE_FILES (a copy): release.build's at their paths in the
# checkout (build/dist/), the Windows workflow's artifact under windows/maestro-windows-packages/. This script may
# only add files: it works on a copy of the packages in a temporary directory and writes the three results to
# dist/finalize/ in the checkout (the release's `files`), never into RELEASE_FILES.
#
# RELEASE_FILES, RELEASE_TAG and RELEASE_VERSION are set by the pipeline. MAESTRO_RELEASE_SECRET_KEY_BASE64 is the
# credential `maestro-signing-key` and MAESTRO_RELEASE_PUBLIC_KEY_BASE64 `maestro-signing-public-key`. As the old job
# did, it signs with both and fails with only one. With neither it fails too, unlike the old job (which published an
# unsigned manifest): `release-manifest.sig` is one of the release's `files`, so an unsigned release could not be
# published anyway. Signing is mandatory.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

files=${RELEASE_FILES:?ci/release-finalize.sh: RELEASE_FILES is not set}
tag=${RELEASE_TAG:?ci/release-finalize.sh: RELEASE_TAG is not set}
# The secret key is read once and then dropped from the environment, so it reaches only the sign_manifest call below,
# not `flutter pub get` or the other tools.
secret_key=${MAESTRO_RELEASE_SECRET_KEY_BASE64:-}
unset MAESTRO_RELEASE_SECRET_KEY_BASE64
public_key=${MAESTRO_RELEASE_PUBLIC_KEY_BASE64:-}
# Where the packages are published: the release's GitHub copy, which is what the manifest's URLs and the installed
# applications use (the old job had it from GITHUB_REPOSITORY and GITHUB_REF_NAME).
download_base="https://github.com/artur-rios/maestro/releases/download/${tag}/"

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
for directory in "$files/build/dist" "$files/windows/maestro-windows-packages"; do
  if [ -d "$directory" ]; then
    find "$directory" -maxdepth 1 -type f -exec cp {} "$work/" \;
  else
    echo "ci/release-finalize.sh: ${directory#"$files"/} is missing" >&2
  fi
done

flutter pub get
# The semantic version of the tag, as the old validate-release job projected it.
versions=$(mktemp)
dart tooling/release/validate_release_tag.dart "$tag" "$versions"
semantic_version=$(sed -n 's/^semantic_version=//p' "$versions")
rm -f "$versions"

dart run tooling/release/create_manifest.dart "$work" "$semantic_version" "$download_base"
if [[ -n "$secret_key" && -n "$public_key" ]]; then
  MAESTRO_RELEASE_SECRET_KEY_BASE64=$secret_key dart run tooling/release/sign_manifest.dart "$work"
elif [[ -z "$secret_key" && -z "$public_key" ]]; then
  echo 'publisher-signing: unconfigured, and a release here must be signed' >&2
  exit 1
else
  echo 'publisher-signing: incomplete signing material' >&2
  exit 1
fi
MAESTRO_RELEASE_PUBLIC_KEY_BASE64=$public_key dart run tooling/release/verify_release.dart "$work"

rm -rf dist/finalize
mkdir -p dist/finalize
cp "$work/release-manifest.json" "$work/SHA256SUMS" dist/finalize/
cp "$work/release-manifest.sig" dist/finalize/
ls -l dist/finalize
