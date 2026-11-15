#!/usr/bin/env bash
# The analyze-test check (GitHub: verify.yml's analyze-test, which ci.yml and release.yml both called): generated
# code is committed, formatting, the architecture and workflow gates, analysis and the whole test suite with
# coverage. The release build runs the same commands before it packages (ci/release-build.sh).
#
# libsqlite3-dev and libsecret-1-dev are what the workflow apt-installed for the native assets and the secret
# storage tests; clang, pkg-config and the GTK, X11 and Xi headers are what window_manager's native library needs,
# which `dart run` and `flutter test` build through its hook. They are installed here with apt when this runs as
# root, as checks do on yggdrasil's agents (ci/apt-packages.sh). The Windows packaging tests need PowerShell, which
# the runner had and the image has not (ci/pwsh.sh).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/apt-packages.sh
source ci/apt-packages.sh
ensure_packages clang pkg-config libgtk-3-dev libx11-dev libxi-dev libsqlite3-dev libsecret-1-dev
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh
# shellcheck source=ci/pwsh.sh
source ci/pwsh.sh
ensure_pwsh

flutter pub get
dart run build_runner build
# Untracked output counts as drift too: a newly generated file that was never committed leaves `git diff` clean.
git status --porcelain
test -z "$(git status --porcelain)"
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
dart run tooling/verify_architecture.dart
dart run tooling/verify_workflows.dart
flutter analyze
flutter test --coverage
