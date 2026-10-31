# shellcheck shell=bash
# Sourced by the scripts under ci/ that run the whole test suite (not run on its own).
#
#     ensure_pwsh
#
# The suite runs tooling/packaging/package_windows.ps1 and the other Windows packaging scripts in their preflight
# mode (test/tooling/windows_*_test.dart), which needs `pwsh`. The GitHub runner had PowerShell installed; no
# Flutter image does, so the pinned release is fetched here, checked against its SHA-256 and put on PATH.
#
# Change POWERSHELL_SHA256 together with the version (Renovate bumps the version, not the checksum): it is in the
# release's assets on GitHub (the asset's digest).

# renovate: datasource=github-releases depName=PowerShell/PowerShell
POWERSHELL_VERSION=7.6.8
POWERSHELL_SHA256=59112e38ad83350e4f6dc0195953c66b5926792f300ca2e7691b8242e7a16e7f

ensure_pwsh() {
  local directory="${TMPDIR:-/tmp}/powershell-$POWERSHELL_VERSION" work
  if [ ! -x "$directory/pwsh" ]; then
    work=$(mktemp -d)
    echo "ci/pwsh.sh: fetching PowerShell $POWERSHELL_VERSION"
    curl --fail --silent --show-error --location --retry 3 -o "$work/powershell.tar.gz" \
      "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-x64.tar.gz"
    echo "$POWERSHELL_SHA256  $work/powershell.tar.gz" | sha256sum --check --strict -
    mkdir -p "$directory"
    tar -xzf "$work/powershell.tar.gz" --no-same-owner -C "$directory"
    rm -rf "$work"
  fi
  export PATH="$directory:$PATH"
  pwsh --version
}
