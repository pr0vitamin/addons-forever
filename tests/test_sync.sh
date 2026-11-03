# End-to-end tests for sync.sh: given Module folders and a config, what ends up
# in the AddOns folder.

test_installs_host_into_addons_folder() {
  run_sync
  assert_sync_ok
  assert_file "$ADDONS/AddonsForever/AddonsForever.toc"
  assert_file "$ADDONS/AddonsForever/Core.lua"
  assert_file "$ADDONS/AddonsForever/Bundle.lua"
}

test_bundle_contains_module_code() {
  add_module Hello "Hello there" Hello.lua
  run_sync
  assert_sync_ok
  local bundle="$ADDONS/AddonsForever/Bundle.lua"
  assert_contains "$bundle" 'AddonsForever:_RegisterModule("Hello", { title = "Hello there" }'
  assert_contains "$bundle" 'path = "modules/Hello/Hello.lua"'
  assert_contains "$bundle" 'local M = AddonsForever:NewModule("Hello")'
  assert_contains "$TMP/sync.out" "synced 1 addon(s)"
}

test_bundle_includes_every_module_in_id_order() {
  add_module Zebra Zebra Zebra.lua
  add_module Apple Apple Apple.lua
  run_sync
  assert_sync_ok
  local order
  order=$(grep -o '_RegisterModule("[A-Za-z]*"' "$ADDONS/AddonsForever/Bundle.lua" | tr '\n' ' ')
  [ "$order" = '_RegisterModule("Apple" _RegisterModule("Zebra" ' ] || fail "unexpected order: $order"
}

test_module_files_bundled_in_manifest_order() {
  add_module Multi Multi Second.lua First.lua
  run_sync
  assert_sync_ok
  local order
  order=$(grep -o 'modules/Multi/[A-Za-z]*\.lua' "$ADDONS/AddonsForever/Bundle.lua" | tr '\n' ' ')
  [ "$order" = 'modules/Multi/Second.lua modules/Multi/First.lua ' ] || fail "unexpected order: $order"
}

test_no_modules_folder_still_installs_host() {
  rm -rf "$MODULES"
  run_sync
  assert_sync_ok
  assert_file "$ADDONS/AddonsForever/Bundle.lua"
  assert_contains "$TMP/sync.out" "no addons found"
}

test_example_hello_module_syncs() {
  cp -R "$REPO_ROOT/examples/Hello" "$MODULES/Hello"
  run_sync
  assert_sync_ok
  assert_contains "$ADDONS/AddonsForever/Bundle.lua" 'AddonsForever:_RegisterModule("Hello"'
}

test_config_with_windows_style_path_and_crlf() {
  printf 'addons_path=%s\r\n' "${ADDONS//\//\\}" > "$CONFIG"
  run_sync
  assert_sync_ok
  assert_file "$ADDONS/AddonsForever/Bundle.lua"
}

test_missing_config_is_reported() {
  rm -f "$CONFIG"
  run_sync
  [ "$SYNC_STATUS" -ne 0 ] || fail "sync should fail without a config"
  assert_contains "$TMP/sync.out" "local.conf.example"
}

test_resync_replaces_bundle() {
  add_module Hello Hello Hello.lua
  run_sync
  assert_sync_ok
  rm -rf "$MODULES/Hello"
  add_module Other Other Other.lua
  run_sync
  assert_sync_ok
  local bundle="$ADDONS/AddonsForever/Bundle.lua"
  assert_contains "$bundle" '_RegisterModule("Other"'
  if grep -qF '_RegisterModule("Hello"' "$bundle"; then fail "stale module left in Bundle"; fi
}

test_module_sources_are_not_modified() {
  add_module Hello Hello Hello.lua
  local before after
  before=$(cd "$MODULES" && find . -type f -exec cksum {} + | sort)
  run_sync
  assert_sync_ok
  after=$(cd "$MODULES" && find . -type f -exec cksum {} + | sort)
  [ "$before" = "$after" ] || fail "Module sources changed during sync"
}

test_code_with_long_brackets_round_trips() {
  add_module Tricky Tricky Tricky.lua
  printf 'local s = [[a]] .. [=[b]=]\nlocal t = "]==]"\n' > "$MODULES/Tricky/Tricky.lua"
  run_sync
  assert_sync_ok
  assert_contains "$ADDONS/AddonsForever/Bundle.lua" 'code = [===['

  local lua
  lua=$(find_lua) || skip "no Lua interpreter installed"
  "$lua" "$REPO_ROOT/tests/bundle_roundtrip.lua" "$ADDONS/AddonsForever/Bundle.lua" "$MODULES" \
    || fail "Bundle code differs from Module sources"
}
