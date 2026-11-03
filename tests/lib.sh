# Shared helpers for tests. Each test runs in its own subshell with $TMP set to
# a fresh temporary folder that is removed afterwards.

setup_tmp() {
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  ADDONS="$TMP/AddOns"
  MODULES="$TMP/modules"
  CONFIG="$TMP/local.conf"
  mkdir -p "$ADDONS" "$MODULES"
  printf 'addons_path=%s\n' "$ADDONS" > "$CONFIG"
}

fail() { printf 'assertion failed: %s\n' "$*" >&2; exit 1; }
skip() { printf '%s\n' "$*"; exit 77; }

# Runs sync against the temporary folders; output goes to $TMP/sync.out.
# Prefix with variables to pass them through, e.g. AF_LUA=none run_sync.
run_sync() {
  set +e
  "$BASH" "$REPO_ROOT/sync.sh" --config "$CONFIG" --modules "$MODULES" "$@" > "$TMP/sync.out" 2>&1
  SYNC_STATUS=$?
  set -e
}

assert_sync_ok() {
  [ "$SYNC_STATUS" -eq 0 ] || fail "sync exited $SYNC_STATUS: $(cat "$TMP/sync.out")"
}

assert_file() { [ -f "$1" ] || fail "expected file $1"; }

assert_contains() {
  grep -qF -- "$2" "$1" || fail "expected $1 to contain: $2"
}

# Writes a Module folder: add_module ID TITLE FILE... (each FILE gets placeholder code).
add_module() {
  local id=$1 title=$2; shift 2
  mkdir -p "$MODULES/$id"
  { printf '## Title: %s\n## Notes: Test addon %s.\n\n' "$title" "$id"; for f in "$@"; do printf '%s\n' "$f"; done; } > "$MODULES/$id/module.toc"
  for f in "$@"; do
    printf 'local M = AddonsForever:NewModule("%s")\nM:Log("loaded %s")\n' "$id" "$f" > "$MODULES/$id/$f"
  done
}

# A Lua interpreter on this machine, if any (only needed for some tests).
find_lua() {
  local t
  for t in lua5.1 luajit lua; do
    if command -v "$t" >/dev/null 2>&1; then printf '%s' "$t"; return 0; fi
  done
  return 1
}

assert_failed_with() {
  [ "$SYNC_STATUS" -ne 0 ] || fail "sync should have failed; output: $(cat "$TMP/sync.out")"
  assert_contains "$TMP/sync.out" "$1"
  [ ! -e "$ADDONS/AddonsForever" ] || fail "a failed sync changed the AddOns folder"
}

# Writes a manifest for an existing or new Module folder: write_toc ID LINE...
write_toc() {
  local id=$1; shift
  mkdir -p "$MODULES/$id"
  printf '%s\n' "$@" > "$MODULES/$id/module.toc"
}
