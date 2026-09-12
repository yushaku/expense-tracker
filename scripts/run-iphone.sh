#!/usr/bin/env bash

# Installs the dev flavour on the physical iPhone, then on this Mac.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device_name="${1:-Yushaku}"
derived_data_path="${MONMON_DERIVED_DATA_PATH:-$project_root/build/DerivedData}"
app_path="$derived_data_path/Build/Products/Debug-iphoneos/MonMon.app"

cd "$project_root"

echo "Building and installing MonMon Dev on iPhone: $device_name"
xcodebuild \
  -project MonMon.xcodeproj \
  -scheme MonMon \
  -configuration Debug \
  -destination "platform=iOS,name=$device_name" \
  -destination-timeout 180 \
  -derivedDataPath "$derived_data_path" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"

xcrun devicectl device install app \
  --device "$device_name" \
  "$app_path"

xcrun devicectl device process launch \
  --terminate-existing \
  --device "$device_name" \
  "$bundle_id"

echo "Building and installing MonMon Dev on this Mac"
# Keep builds sequential: both destinations use the workspace DerivedData cache.
bash "$project_root/scripts/install-mac.sh" dev

echo "MonMon Dev installed and launched on iPhone ($device_name) and Mac"
