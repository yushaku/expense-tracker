#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$project_root/build/tests"
test_root="$(mktemp -d "$project_root/build/tests/run-iphone.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
fixture="$test_root/workspace with spaces"
mkdir -p "$fixture/scripts" "$test_root/bin"
cp "$project_root/scripts/run-iphone.sh" "$fixture/scripts/"

cat >"$test_root/bin/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MONMON_TEST_BRANCH:-dev}"
EOF
cat >"$test_root/bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo 'iphone build' >>"$MONMON_TEST_LOG"
[[ "${MONMON_TEST_FAILURE:-}" != build ]] || exit 71
app="$MONMON_DERIVED_DATA_PATH/Build/Products/Debug-iphoneos/MonMon.app"
mkdir -p "$app"
cat >"$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>test.monmon.dev</string></dict></plist>
PLIST
EOF
cat >"$test_root/bin/xcrun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >>"$MONMON_TEST_LOG"
if [[ "${MONMON_TEST_FAILURE:-}" == install && "$*" == *'device install app'* ]]; then exit 72; fi
if [[ "${MONMON_TEST_FAILURE:-}" == launch && "$*" == *'device process launch'* ]]; then exit 73; fi
EOF
cat >"$fixture/scripts/install-mac.sh" <<'EOF'
#!/usr/bin/env bash
echo "mac install $*" >>"$MONMON_TEST_LOG"
[[ "${MONMON_TEST_FAILURE:-}" != mac ]] || exit 74
EOF
chmod +x "$test_root/bin/"*

run() {
  env PATH="$test_root/bin:/usr/bin:/bin" \
    MONMON_TEST_LOG="$test_root/commands.log" \
    MONMON_DERIVED_DATA_PATH="$test_root/shared cache" \
    bash "$fixture/scripts/run-iphone.sh" "$@"
}
fail() { echo "FAIL: $*" >&2; exit 1; }

: >"$test_root/commands.log"
run 'My iPhone' >"$test_root/success.log"
[[ "$(head -n 1 "$test_root/commands.log")" == 'iphone build' ]] || fail 'iPhone must build first'
grep -F 'device install app --device My iPhone' "$test_root/commands.log" >/dev/null || fail 'device argument lost'
grep -F 'device process launch --terminate-existing --device My iPhone test.monmon.dev' "$test_root/commands.log" >/dev/null || fail 'wrong launch'
[[ "$(tail -n 1 "$test_root/commands.log")" == 'mac install dev' ]] || fail 'Mac must install last as dev'
grep -F 'installed and launched on iPhone (My iPhone) and Mac' "$test_root/success.log" >/dev/null || fail 'missing success summary'

: >"$test_root/commands.log"
run >"$test_root/default.log"
grep -F -- '--device Yushaku' "$test_root/commands.log" >/dev/null || fail 'default device changed'

for branch in main feat/example; do
  : >"$test_root/commands.log"
  if MONMON_TEST_BRANCH="$branch" run >"$test_root/refusal.log" 2>&1; then fail 'branch guard missing'; fi
  [[ ! -s "$test_root/commands.log" ]] || fail 'branch guard must precede all builds/installs'
done

for stage in build install launch mac; do
  : >"$test_root/commands.log"
  if MONMON_TEST_FAILURE="$stage" run >"$test_root/failure.log" 2>&1; then fail "ignored $stage failure"; fi
  if grep -F 'installed and launched on iPhone' "$test_root/failure.log" >/dev/null; then fail 'false success'; fi
  if [[ "$stage" != mac ]] && grep -F 'mac install' "$test_root/commands.log" >/dev/null; then fail 'Mac ran after iPhone failure'; fi
done

echo 'Combined iPhone and Mac installer tests passed'
