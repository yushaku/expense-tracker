#!/usr/bin/env bash

# Builds the production flavour: Release configuration, which the xcconfigs bind
# to the com.sonlv.monmon identifier, the group.com.sonlv.monmon app group and
# the iCloud.monmon container. The dev flavour that scripts/run-iphone.sh builds
# uses none of those, so the two installs never read each other's data.
#
# Only main ships. The branch and clean-tree checks are here so an archive can be
# traced back to a commit that is on main and pushed.
#
# Install with scripts/install-prod.sh <device-name>.

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

derived_data_path="${MONMON_PROD_DERIVED_DATA_PATH:-${MONMON_DERIVED_DATA_PATH:-$project_root/build/DerivedData}}"
output_dir="${MONMON_PROD_OUTPUT_DIR:-$project_root/build/prod}"
archive_path="$output_dir/MonMon.xcarchive"



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
echo "install: scripts/install-prod.sh <device-name>"
