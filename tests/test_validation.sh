# End-to-end tests for sync's checks: problems are reported clearly, every
# problem is reported in one run, and nothing is installed until they're fixed.

test_missing_title_is_reported() {
  write_toc NoTitle '## Notes: Something.' 'NoTitle.lua'
  printf 'local x = 1\n' > "$MODULES/NoTitle/NoTitle.lua"
  run_sync
  assert_failed_with 'addon NoTitle: module.toc is missing "## Title:"'
}

test_missing_notes_is_reported() {
  write_toc NoNotes '## Title: No notes' 'NoNotes.lua'
  printf 'local x = 1\n' > "$MODULES/NoNotes/NoNotes.lua"
  run_sync
  assert_failed_with 'addon NoNotes: module.toc is missing "## Notes:"'
}

test_manifest_without_files_is_reported() {
  write_toc Empty '## Title: Empty' '## Notes: Nothing here.'
  run_sync
  assert_failed_with "addon Empty: module.toc doesn't list any .lua files"
}

test_missing_file_is_reported() {
  write_toc Gone '## Title: Gone' '## Notes: Missing file.' 'Gone.lua'
  run_sync
  assert_failed_with 'addon Gone: module.toc lists Gone.lua, but that file does not exist'
}

test_file_outside_module_folder_is_reported() {
  add_module Sneaky Sneaky Sneaky.lua
  printf '../Other/Thing.lua\n' >> "$MODULES/Sneaky/module.toc"
  run_sync
  assert_failed_with 'addon Sneaky: module.toc lists "../Other/Thing.lua", which is outside the addon'"'"'s folder'
}

test_non_lua_file_is_reported() {
  add_module Frames Frames Frames.lua
  printf 'Frames.xml\n' >> "$MODULES/Frames/module.toc"
  printf '<Ui/>\n' > "$MODULES/Frames/Frames.xml"
  run_sync
  assert_failed_with 'addon Frames: module.toc lists "Frames.xml", but only .lua files are supported'
}

test_invalid_folder_name_is_reported() {
  add_module "1stTry" "First try" First.lua
  run_sync
  assert_failed_with 'addon folder "1stTry": the folder name is the addon'"'"'s id'
}

test_folder_name_with_space_is_reported() {
  add_module "My Addon" "Mine" Mine.lua
  run_sync
  assert_failed_with 'addon folder "My Addon"'
}

test_every_problem_is_reported_in_one_run() {
  write_toc NoTitle '## Notes: Something.' 'NoTitle.lua'
  printf 'local x = 1\n' > "$MODULES/NoTitle/NoTitle.lua"
  write_toc Gone '## Title: Gone' '## Notes: Missing file.' 'Gone.lua'
  add_module Fine Fine Fine.lua
  run_sync
  assert_failed_with 'found 2 problem(s); nothing was installed'
  assert_contains "$TMP/sync.out" 'addon NoTitle'
  assert_contains "$TMP/sync.out" 'addon Gone'
}

test_duplicate_ids_ignoring_case_are_reported() {
  mkdir -p "$MODULES/Probe"
  if [ -d "$MODULES/probe" ]; then
    skip "this filesystem ignores letter case, so two such folders can't exist"
  fi
  rm -rf "$MODULES/Probe"
  add_module Hello Hello Hello.lua
  add_module hello hello hello.lua
  run_sync
  assert_failed_with 'two addons have the id "hello" (ignoring letter case)'
}

test_listing_a_file_twice_warns_and_loads_it_once() {
  add_module Twice Twice Twice.lua
  printf 'Twice.lua\n' >> "$MODULES/Twice/module.toc"
  run_sync
  assert_sync_ok
  assert_contains "$TMP/sync.out" 'lists Twice.lua more than once'
  local n
  n=$(grep -c 'path = "modules/Twice/Twice.lua"' "$ADDONS/AddonsForever/Bundle.lua")
  [ "$n" -eq 1 ] || fail "Twice.lua bundled $n times"
}

test_folder_without_manifest_is_skipped_with_warning() {
  mkdir -p "$MODULES/Scratch"
  printf 'notes\n' > "$MODULES/Scratch/ideas.txt"
  add_module Hello Hello Hello.lua
  run_sync
  assert_sync_ok
  assert_contains "$TMP/sync.out" "skipping folder Scratch: it has no module.toc"
  assert_contains "$TMP/sync.out" "synced 1 addon(s)"
}

# Lua syntax -----------------------------------------------------------------------

test_lua_syntax_error_is_reported_with_file_and_line() {
  local lua
  lua=$(find_lua) || skip "no Lua interpreter installed"
  add_module Broken Broken Broken.lua
  printf 'local M = AddonsForever:NewModule("Broken")\nthis is not lua\n' > "$MODULES/Broken/Broken.lua"
  AF_LUA=$lua run_sync
  assert_failed_with 'Lua syntax error: modules/Broken/Broken.lua:2:'
}

test_syntax_errors_in_several_addons_are_all_reported() {
  local lua
  lua=$(find_lua) || skip "no Lua interpreter installed"
  add_module One One One.lua
  add_module Two Two Two.lua
  printf 'local = 1\n' > "$MODULES/One/One.lua"
  printf 'end\n' > "$MODULES/Two/Two.lua"
  AF_LUA=$lua run_sync
  assert_failed_with 'found 2 problem(s)'
  assert_contains "$TMP/sync.out" 'modules/One/One.lua:1:'
  assert_contains "$TMP/sync.out" 'modules/Two/Two.lua:1:'
}

test_syntax_check_can_be_turned_off() {
  add_module Broken Broken Broken.lua
  printf 'this is not lua\n' > "$MODULES/Broken/Broken.lua"
  AF_LUA=none run_sync
  assert_sync_ok
  assert_contains "$TMP/sync.out" 'Lua syntax check turned off'
}

test_without_lua_sync_notes_the_skip_and_continues() {
  local p
  for p in luajit lua5.1 lua; do
    if PATH=/usr/bin:/bin command -v "$p" >/dev/null 2>&1; then
      skip "a Lua interpreter is installed in /usr/bin or /bin"
    fi
  done
  add_module Hello Hello Hello.lua
  PATH=/usr/bin:/bin run_sync
  assert_sync_ok
  assert_contains "$TMP/sync.out" 'no Lua interpreter found, so Lua syntax was not checked'
}

test_unknown_lua_program_is_reported() {
  add_module Hello Hello Hello.lua
  AF_LUA=no-such-lua-program run_sync
  [ "$SYNC_STATUS" -ne 0 ] || fail "sync should fail when AF_LUA names a missing program"
  assert_contains "$TMP/sync.out" 'AF_LUA is set to no-such-lua-program, but that program was not found'
}

# Config ---------------------------------------------------------------------------

test_unset_addons_path_is_reported() {
  printf '# nothing here\naddons_path=\n' > "$CONFIG"
  run_sync
  [ "$SYNC_STATUS" -ne 0 ] || fail "sync should fail without addons_path"
  assert_contains "$TMP/sync.out" 'addons_path is not set'
}

test_nonexistent_addons_path_is_reported() {
  printf 'addons_path=%s\n' "$TMP/Nowhere/AddOns" > "$CONFIG"
  run_sync
  [ "$SYNC_STATUS" -ne 0 ] || fail "sync should fail for a missing folder"
  assert_contains "$TMP/sync.out" "AddOns folder not found: $TMP/Nowhere/AddOns"
  assert_contains "$TMP/sync.out" 'Interface/AddOns folder inside your WoW install'
}

test_addons_path_not_ending_in_addons_warns() {
  mkdir -p "$TMP/Interface"
  printf 'addons_path=%s\n' "$TMP/Interface" > "$CONFIG"
  run_sync
  assert_sync_ok
  assert_contains "$TMP/sync.out" "doesn't end in AddOns"
}

test_config_tolerates_spaces_around_equals_and_trailing_slash() {
  printf 'addons_path = %s/\n' "$ADDONS" > "$CONFIG"
  run_sync
  assert_sync_ok
  assert_file "$ADDONS/AddonsForever/Bundle.lua"
}
