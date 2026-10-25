#!/usr/bin/env bash
# The release's validation (`release.validate` in yggdrasil.yml). It is pass or fail: the pipeline uploads the set
# it took before this ran, so nothing here can change what is published.
#
# It ports what the old release job's verify_release.dart checked of the packages (validateDistributionPackages in
# tooling/release/release_artifacts.dart): exactly the five distribution packages of
# docs/development/releases-and-signing.md, each non-empty, and no other package. The manifest, the checksum list
# and the signature that verify_release.dart checked next are not here: nothing makes them yet (see ci/release-build.sh).
#
# The pipeline puts the release's files under RELEASE_FILES (a copy): release.build's at their paths in the checkout
# (build/dist/), the Windows workflow's artifact under windows/maestro-windows-packages/. A release whose Windows
# files are missing (the GitHub Actions checks skipped, or the Windows run failed) fails here, as a release without
# them never passed this validation on GitHub: finish it with yggdrasil's release-resume job.
#
# RELEASE_FILES, RELEASE_TAG and RELEASE_VERSION are set by the pipeline.
set -euo pipefail

files=${RELEASE_FILES:?ci/release-validate.sh: RELEASE_FILES is not set}

expected=$(printf '%s\n' \
  maestro-linux-amd64.deb \
  maestro-linux-x64.AppImage \
  maestro-windows-x64-setup.exe \
  maestro-windows-x64.msix \
  maestro-windows-x64.zip)

bundle=$(mktemp -d)
trap 'rm -rf -- "$bundle"' EXIT
for directory in "$files/build/dist" "$files/windows/maestro-windows-packages"; do
  if [ -d "$directory" ]; then
    find "$directory" -maxdepth 1 -type f -exec cp {} "$bundle/" \;
  else
    echo "ci/release-validate.sh: ${directory#"$files"/} is missing" >&2
  fi
done

# The packages are the files with one of the managed extensions (the tooling's _managedPackageExtensions).
actual=$(cd "$bundle" && find . -maxdepth 1 -type f \
  \( -iname '*.zip' -o -iname '*.msix' -o -iname '*.exe' -o -iname '*.appimage' -o -iname '*.deb' \) \
  -printf '%f\n' | LC_ALL=C sort)
if [ "$actual" != "$expected" ]; then
  echo "ci/release-validate.sh: the distribution packages do not match the required package set." >&2
  echo "required:" >&2
  printf '%s\n' "$expected" | sed 's/^/  /' >&2
  echo "found:" >&2
  printf '%s\n' "$actual" | sed 's/^/  /' >&2
  exit 1
fi
status=0
while IFS= read -r name; do
  if [ ! -s "$bundle/$name" ]; then
    echo "ci/release-validate.sh: distribution package is empty: $name" >&2
    status=1
  fi
done <<<"$expected"
exit "$status"
