#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
device_name="${1:-Yushaku}"
derived_data_path="${MONMON_DERIVED_DATA_PATH:-/tmp/MonMonDeviceDerivedData}"
app_path="$derived_data_path/Build/Products/Debug-iphoneos/MonMon.app"

cd "$project_root"

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
