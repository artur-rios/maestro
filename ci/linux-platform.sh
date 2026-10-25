#!/usr/bin/env bash
# The linux-platform check (GitHub: ci.yml's linux-platform): the Linux desktop integration tests under a virtual
# display (and one with a Secret Service keyring), the Linux release build, and the AppImage and Debian packages
# with their install and update smoke test. The Windows leg stays a GitHub Actions job, "windows-platform".
#
# The Linux desktop prerequisites are installed with apt when this runs as root, as checks do on yggdrasil's
# agents (ci/apt-packages.sh); libsqlite3-dev is in the list because this job builds and links the application,
# so it must not rely on the image happening to provide the sqlite3 development files its native assets need.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/apt-packages.sh
source ci/apt-packages.sh
ensure_packages clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libsqlite3-dev libjsoncpp-dev \
  libayatana-appindicator3-dev dbus-x11 gnome-keyring xvfb
# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh
# shellcheck source=ci/appimagetool.sh
source ci/appimagetool.sh

flutter pub get
xvfb-run -a flutter test integration_test/platform/process_tree_integration_test.dart -d linux
# Production startup integration with Secret Service.
dbus-run-session -- bash -euc '
  printf "\n" | gnome-keyring-daemon --unlock
  xvfb-run -a flutter test integration_test/foundation_startup_integration_test.dart -d linux
'
xvfb-run -a flutter test integration_test/performance/concurrent_streams_integration_test.dart -d linux
xvfb-run -a flutter test integration_test/performance/run_observation_integration_test.dart -d linux
xvfb-run -a flutter test integration_test/terminal/embedded_terminal_integration_test.dart -d linux
xvfb-run -a flutter test integration_test/projects/git_project_validation_integration_test.dart -d linux
xvfb-run -a flutter test integration_test/projects/project_lifecycle_non_ownership_integration_test.dart -d linux
xvfb-run -a flutter test integration_test/workflows/workflow_design_persistence_integration_test.dart -d linux
xvfb-run -a flutter test integration_test/workflows/step_agent_process_integration_test.dart -d linux
flutter build linux --release

ensure_appimagetool
bash tooling/packaging/package_linux.sh 0.1.0 0.1.0 0.1.0
bash tooling/smoke/linux_install_update.sh dist/maestro-linux-x64.AppImage dist/maestro-linux-amd64.deb
