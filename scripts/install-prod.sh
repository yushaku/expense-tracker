#!/usr/bin/env bash

# Installs and launches the last prod archive built by scripts/build-prod.sh.
# Does not rebuild. Pass the device name as shown by `xcrun devicectl list devices`.

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

device_name="${1:-}"
output_dir="${MONMON_PROD_OUTPUT_DIR:-$project_root/build/prod}"
archive_path="$output_dir/MonMon.xcarchive"
app_path="$archive_path/Products/Applications/MonMon.app"

if [[ -z "$device_name" ]]; then
  echo "usage: scripts/install-prod.sh <device-name>" >&2
  exit 1
fi

if [[ ! -d "$app_path" ]]; then
  echo "refusing: no prod app at $app_path; run scripts/build-prod.sh first" >&2
  exit 1
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"

xcrun devicectl device install app \
  --device "$device_name" \
  "$app_path"

xcrun devicectl device process launch \
  --terminate-existing \
  --device "$device_name" \
  "$bundle_id"
