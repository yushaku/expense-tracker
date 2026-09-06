#!/usr/bin/env bash

# Builds, installs, and launches a local macOS flavour. Installs into
# ~/Applications by default so administrator privileges are not required.

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

flavour="${1:-dev}"
derived_data_path="${MONMON_MAC_DERIVED_DATA_PATH:-${MONMON_DERIVED_DATA_PATH:-$project_root/build/DerivedData}}"
install_dir="${MONMON_MAC_INSTALL_DIR:-$HOME/Applications}"

case "$flavour" in
  dev)
    configuration="Debug"
    installed_app_name="MonMon Dev.app"
    ;;
  prod)
    configuration="Release"
    installed_app_name="MonMon.app"

    branch="$(git rev-parse --abbrev-ref HEAD)"
    if [[ "$branch" != "main" ]]; then
      echo "refusing: prod installs come from main, not '$branch'" >&2
      exit 1
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
      echo "refusing: working tree is dirty; commit or stash first" >&2
      exit 1
    fi

    git fetch --quiet origin main 2>/dev/null || true
    if git rev-parse --quiet --verify origin/main >/dev/null; then
      if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
        echo "refusing: HEAD is not origin/main; push or pull first" >&2
        exit 1
      fi
    fi
    ;;
  *)
    echo "usage: scripts/install-mac.sh [dev|prod]" >&2
    exit 1
    ;;
esac

if [[ -z "$install_dir" || "$install_dir" == "/" ]]; then
  echo "refusing: unsafe macOS install directory '$install_dir'" >&2
  exit 1
fi

app_path="$derived_data_path/Build/Products/$configuration/MonMon.app"
install_path="$install_dir/$installed_app_name"

xcodebuild \
  -project MonMon.xcodeproj \
  -scheme MonMon \
  -configuration "$configuration" \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$derived_data_path" \
  -allowProvisioningUpdates \
  build

if [[ ! -d "$app_path" ]]; then
  echo "build succeeded but no app was found at $app_path" >&2
  exit 1
fi

mkdir -p "$install_dir"
rm -rf "$install_path"
ditto "$app_path" "$install_path"
open "$install_path"

echo "installed: $install_path"
