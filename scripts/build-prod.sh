#!/usr/bin/env bash

# Builds the production flavour: Release configuration, which the xcconfigs bind
# to the com.sonlv.monmon identifier, the group.com.sonlv.monmon app group and
# the iCloud.monmon container. The dev flavour that scripts/run-iphone.sh builds
# uses none of those, so the two installs never read each other's data.
#
# Only main ships. The branch and clean-tree checks are here so an archive can be
# traced back to a commit that is on main and pushed.

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

device_name="${1:-}"
derived_data_path="${MONMON_PROD_DERIVED_DATA_PATH:-/tmp/MonMonProdDerivedData}"
output_dir="${MONMON_PROD_OUTPUT_DIR:-$project_root/build/prod}"
archive_path="$output_dir/MonMon.xcarchive"

branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$branch" != "main" ]]; then
  echo "refusing: prod builds come from main, not '$branch'" >&2
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

rm -rf "$archive_path"
mkdir -p "$output_dir"

xcodebuild \
  -project MonMon.xcodeproj \
  -scheme MonMon \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$derived_data_path" \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath "$output_dir" \
  -allowProvisioningUpdates

echo "archive: $archive_path"
echo "ipa:     $output_dir/MonMon.ipa"

if [[ -z "$device_name" ]]; then
  exit 0
fi

app_path="$archive_path/Products/Applications/MonMon.app"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"

xcrun devicectl device install app \
  --device "$device_name" \
  "$app_path"

xcrun devicectl device process launch \
  --terminate-existing \
  --device "$device_name" \
  "$bundle_id"
