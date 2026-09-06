#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$project_root/scripts/install-mac.sh"
mkdir -p "$project_root/build/tests"
test_root="$(mktemp -d "$project_root/build/tests/monmon-install-mac-tests.XXXXXX")"
fake_bin="$test_root/bin"
command_log="$test_root/commands.log"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$fake_bin"

cat >"$fake_bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'xcodebuild %s\n' "$*" >>"$MONMON_TEST_COMMAND_LOG"

configuration=""
derived_data_path=""
while (($#)); do
  case "$1" in
    -configuration)
      configuration="$2"
      shift 2
      ;;
    -derivedDataPath)
      derived_data_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

app_path="$derived_data_path/Build/Products/$configuration/MonMon.app"
mkdir -p "$app_path"
touch "$app_path/built-by-test"
EOF

cat >"$fake_bin/ditto" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'ditto %s\n' "$*" >>"$MONMON_TEST_COMMAND_LOG"
cp -R "$1" "$2"
EOF

cat >"$fake_bin/open" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'open %s\n' "$*" >>"$MONMON_TEST_COMMAND_LOG"
EOF

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  "rev-parse --abbrev-ref HEAD")
    printf '%s\n' "${MONMON_TEST_GIT_BRANCH:-main}"
    ;;
  "status --porcelain")
    printf '%s' "${MONMON_TEST_GIT_STATUS:-}"
    ;;
  "fetch --quiet origin main")
    ;;
  "rev-parse --quiet --verify origin/main")
    printf '%s\n' "${MONMON_TEST_ORIGIN_MAIN:-abc123}"
    ;;
  "rev-parse HEAD")
    printf '%s\n' "${MONMON_TEST_HEAD:-abc123}"
    ;;
  "rev-parse origin/main")
    printf '%s\n' "${MONMON_TEST_ORIGIN_MAIN:-abc123}"
    ;;
  *)
    printf 'unexpected git command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

chmod +x "$fake_bin/xcodebuild" "$fake_bin/ditto" "$fake_bin/open" "$fake_bin/git"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_log_contains() {
  local expected="$1"
  grep -F -- "$expected" "$command_log" >/dev/null || fail "command log does not contain: $expected"
}

run_installer() {
  PATH="$fake_bin:/usr/bin:/bin" \
    MONMON_TEST_COMMAND_LOG="$command_log" \
    MONMON_MAC_DERIVED_DATA_PATH="$test_root/derived" \
    MONMON_MAC_INSTALL_DIR="$test_root/Applications" \
    "$script" "$@"
}

: >"$command_log"
run_installer dev
[[ -f "$test_root/Applications/MonMon Dev.app/built-by-test" ]] || fail "dev app was not installed"
assert_log_contains "-configuration Debug"
assert_log_contains "open $test_root/Applications/MonMon Dev.app"

: >"$command_log"
if MONMON_TEST_GIT_BRANCH="feat/not-main" run_installer prod >"$test_root/prod-error.log" 2>&1; then
  fail "prod install succeeded outside main"
fi
grep -F "prod installs come from main" "$test_root/prod-error.log" >/dev/null \
  || fail "prod branch guard did not explain the refusal"
[[ ! -s "$command_log" ]] || fail "prod branch guard ran build commands"

: >"$command_log"
MONMON_TEST_GIT_BRANCH="main" run_installer prod
[[ -f "$test_root/Applications/MonMon.app/built-by-test" ]] || fail "prod app was not installed"
assert_log_contains "-configuration Release"
assert_log_contains "open $test_root/Applications/MonMon.app"

if run_installer preview >"$test_root/usage-error.log" 2>&1; then
  fail "unsupported flavour succeeded"
fi
grep -F "usage: scripts/install-mac.sh [dev|prod]" "$test_root/usage-error.log" >/dev/null \
  || fail "unsupported flavour did not print usage"

printf 'install-mac tests passed\n'
