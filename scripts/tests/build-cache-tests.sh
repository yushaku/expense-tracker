#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$project_root/build/tests"
test_root="$(mktemp -d "$project_root/build/tests/cache-paths.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
fixture="$test_root/workspace with spaces"
mkdir -p "$fixture/scripts" "$test_root/bin"
cp "$project_root/scripts/"{run-iphone,install-mac,build-prod}.sh "$fixture/scripts/"

# Stop at the build boundary: never build, install, launch, fetch, or archive.
cat >"$test_root/bin/xcodebuild" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$MONMON_TEST_COMMAND_LOG"
exit 73
EOF
cat >"$test_root/bin/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "rev-parse --abbrev-ref HEAD") printf '%s\n' "${MONMON_TEST_GIT_BRANCH:-main}" ;;
  "status --porcelain" | "fetch --quiet origin main") ;;
  *) printf 'fixture-head\n' ;;
esac
EOF
chmod +x "$test_root/bin/"*

check_path() {
  local script="$1" argument="$2" expected="$3"
  shift 3
  local status=0
  local branch="main"
  [[ "$script" != run-iphone.sh ]] || branch="dev"
  (
    cd "$test_root"
    env -u MONMON_DERIVED_DATA_PATH -u MONMON_MAC_DERIVED_DATA_PATH \
      -u MONMON_PROD_DERIVED_DATA_PATH -u MONMON_PROD_OUTPUT_DIR \
      PATH="$test_root/bin:/usr/bin:/bin" \
      MONMON_TEST_GIT_BRANCH="$branch" \
      MONMON_TEST_COMMAND_LOG="$test_root/command.log" "$@" \
      bash "$fixture/scripts/$script" "$argument"
  ) || status=$?
  [[ "$status" == 73 ]] || { echo "Unexpected exit: $script ($status)"; exit 1; }
  grep -Fx -- "$expected" "$test_root/command.log" >/dev/null \
    || { echo "Wrong cache path: $script"; cat "$test_root/command.log"; exit 1; }
}

cache="$fixture/build/DerivedData"
mkdir -p "$cache"
printf 'existing cache\n' >"$cache/keep-me"
for script in run-iphone.sh install-mac.sh build-prod.sh; do
  argument="dev"
  [[ "$script" != run-iphone.sh ]] || argument="Yushaku"
  check_path "$script" "$argument" "$cache"
  check_path "$script" "$argument" "$cache"
  [[ -f "$cache/keep-me" ]] || { echo "Existing cache was removed"; exit 1; }
  check_path "$script" "$argument" "$test_root/custom cache" \
    MONMON_DERIVED_DATA_PATH="$test_root/custom cache"
done
check_path install-mac.sh dev "$test_root/mac cache" \
  MONMON_DERIVED_DATA_PATH="$test_root/shared" MONMON_MAC_DERIVED_DATA_PATH="$test_root/mac cache"
check_path build-prod.sh prod "$test_root/prod cache" \
  MONMON_DERIVED_DATA_PATH="$test_root/shared" MONMON_PROD_DERIVED_DATA_PATH="$test_root/prod cache"

echo "Workspace cache path tests passed"
