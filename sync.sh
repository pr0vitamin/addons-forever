#!/usr/bin/env bash
# Addons Forever sync.
#
# Checks every Module, builds the Bundle and installs the Host into the game's
# AddOns folder. Afterwards, type /reload in game.
#
# Usage: ./sync.sh [--config FILE] [--modules DIR]
#   --config FILE   local config to read (default: local.conf next to this script)
#   --modules DIR   folder holding Module folders (default: modules/ next to this script)
#
# Environment:
#   AF_LUA=PROGRAM  Lua interpreter for the syntax check (default: the first of
#                   luajit, lua5.1, lua that is installed); AF_LUA=none skips it
#
# Must run on bash 3.2 (macOS) as well as Git Bash on Windows. Per-line and
# per-file work avoids $(...) and external commands: each one starts a process,
# which is slow in Git Bash.

set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$ROOT/local.conf"
MODULES_DIR="$ROOT/modules"
HOST_DIR="$ROOT/host"
HOST_NAME="AddonsForever"
ID_PATTERN='^[A-Za-z][A-Za-z0-9_]*$'
NL=$'\n'

die() { printf 'sync: error: %s\n' "$*" >&2; exit 1; }
note() { printf 'sync: %s\n' "$*"; }
warn() { printf 'sync: warning: %s\n' "$*" >&2; }

errors=()
problem() { errors+=("$*"); }

# Helpers set REPLY instead of printing, so callers don't need $(...).

trim() {
  REPLY="${1#"${1%%[![:space:]]*}"}"
  REPLY="${REPLY%"${REPLY##*[![:space:]]}"}"
}

# A Lua double-quoted string literal.
lua_quote() {
  REPLY=${1//\\/\\\\}
  REPLY="\"${REPLY//\"/\\\"}\""
}

read_file() {
  REPLY=""
  IFS= read -r -d '' REPLY < "$1" || true
}

# The "=" padding for a Lua long bracket whose opening and closing forms do not
# occur in $1. Always at least one "=": WoW's Lua 5.1 rejects any "[[" inside a
# level-0 "[[ ]]" string, which would stop the whole Bundle from loading.
long_level() {
  local eq="="
  while [[ $1 == *"]${eq}]"* || $1 == *"[${eq}["* ]]; do
    eq="${eq}="
  done
  REPLY=$eq
}

while [ $# -gt 0 ]; do
  case "$1" in
    --config) [ $# -ge 2 ] || die "--config needs a file"; CONFIG=$2; shift 2 ;;
    --modules) [ $# -ge 2 ] || die "--modules needs a folder"; MODULES_DIR=$2; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

# Config -----------------------------------------------------------------------

[ -f "$CONFIG" ] || die "no config found at $CONFIG. Copy local.conf.example to local.conf and set addons_path to your WoW AddOns folder."

addons_path=""
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'}
  trim "$line"
  case "$REPLY" in
    addons_path*=*)
      key=${REPLY%%=*}
      trim "$key"
      [ "$REPLY" = addons_path ] || continue
      trim "${line#*=}"
      addons_path=$REPLY
      ;;
  esac
done < "$CONFIG"

case "$addons_path" in
  \"*\"|\'*\') addons_path=${addons_path:1:${#addons_path}-2} ;;
esac
addons_path=${addons_path//\\//}
addons_path=${addons_path%/}
[ -n "$addons_path" ] || die "addons_path is not set in $CONFIG. Set it to your WoW AddOns folder, for example addons_path=C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
[ -d "$addons_path" ] || die "AddOns folder not found: $addons_path. Check addons_path in $CONFIG; it should be the Interface/AddOns folder inside your WoW install."
case "$addons_path" in
  */[Aa][Dd][Dd][Oo][Nn][Ss]) ;;
  *) warn "addons_path ($addons_path) doesn't end in AddOns; the game only loads addons from its Interface/AddOns folder." ;;
esac

dest="$addons_path/$HOST_NAME"

# Check Modules --------------------------------------------------------------------

mod_ids=()     # per Module
mod_titles=()
mod_notes=()
mod_first=()   # index of its first entry in the file_* arrays
mod_nfiles=()
file_src=()    # per file: path on disk, and its chunk name in game
file_chunk=()
id_list=""

if [ -d "$MODULES_DIR" ]; then
  for dir in "$MODULES_DIR"/*/; do
    [ -d "$dir" ] || continue
    dir=${dir%/}
    id=${dir##*/}
    toc="$dir/module.toc"
    if [ ! -f "$toc" ]; then
      warn "skipping folder $id: it has no module.toc, so it isn't an addon"
      continue
    fi

    [[ $id =~ $ID_PATTERN ]] || problem "addon folder \"$id\": the folder name is the addon's id, so it must start with a letter and use only letters, digits and _"

    title=""
    notes=""
    listed=0
    first=${#file_src[@]}
    seen=$NL
    while IFS= read -r line || [ -n "$line" ]; do
      trim "${line%$'\r'}"
      line=$REPLY
      case "$line" in
        "## Title:"*) trim "${line#"## Title:"}"; title=$REPLY ;;
        "## Notes:"*) trim "${line#"## Notes:"}"; notes=$REPLY ;;
        "#"*|"") ;;
        *)
          listed=$((listed + 1))
          f=${line//\\//}
          case "$f" in
            /*|[A-Za-z]:*|..|../*|*/..|*/../*)
              problem "addon $id: module.toc lists \"$f\", which is outside the addon's folder; list files relative to its folder"
              continue ;;
          esac
          case "$f" in
            *.[Ll][Uu][Aa]) ;;
            *) problem "addon $id: module.toc lists \"$f\", but only .lua files are supported"; continue ;;
          esac
          if [ ! -f "$dir/$f" ]; then
            problem "addon $id: module.toc lists $f, but that file does not exist in the addon's folder"
            continue
          fi
          case "$seen" in
            *"$NL$f$NL"*) warn "addon $id: module.toc lists $f more than once; loading it once"; continue ;;
          esac
          seen="$seen$f$NL"
          file_src+=("$dir/$f")
          file_chunk+=("modules/$id/$f")
          ;;
      esac
    done < "$toc"

    [ -n "$title" ] || problem "addon $id: module.toc is missing \"## Title:\" (the addon's display name)"
    [ -n "$notes" ] || problem "addon $id: module.toc is missing \"## Notes:\" (a one-line description of what the addon does)"
    [ "$listed" -gt 0 ] || problem "addon $id: module.toc doesn't list any .lua files to load"

    mod_ids+=("$id")
    mod_titles+=("$title")
    mod_notes+=("$notes")
    mod_first+=("$first")
    mod_nfiles+=($(( ${#file_src[@]} - first )))
    id_list="$id_list$id$NL"
  done
fi

# Ids are compared ignoring case, because slash commands ignore case.
if [ ${#mod_ids[@]} -gt 1 ]; then
  dups=$(printf '%s' "$id_list" | tr 'A-Z' 'a-z' | sort | uniq -d)
  for d in $dups; do
    problem "two addons have the id \"$d\" (ignoring letter case); rename one of their folders"
  done
fi

# Lua syntax ---------------------------------------------------------------------

lua_tool=""
case "${AF_LUA:-}" in
  none) note "Lua syntax check turned off (AF_LUA=none)." ;;
  "")
    for t in luajit lua5.1 lua; do
      if command -v "$t" >/dev/null 2>&1; then lua_tool=$t; break; fi
    done
    [ -n "$lua_tool" ] || note "no Lua interpreter found, so Lua syntax was not checked. Syntax errors will show in the Debug Log after /reload."
    ;;
  *)
    command -v "$AF_LUA" >/dev/null 2>&1 || die "AF_LUA is set to $AF_LUA, but that program was not found"
    lua_tool=$AF_LUA
    ;;
esac

if [ -n "$lua_tool" ] && [ ${#file_src[@]} -gt 0 ]; then
  args=()
  for ((i = 0; i < ${#file_src[@]}; i++)); do
    args+=("${file_src[$i]}" "${file_chunk[$i]}")
  done
  # One Lua process checks every file, compiling it under the same chunk name
  # the Host uses in game, so errors read "modules/<id>/<file>:<line>: ...".
  syntax_out=$("$lua_tool" - "${args[@]}" <<'LUA'
local compile = loadstring or load
for i = 1, #arg, 2 do
  local f = assert(io.open(arg[i], "rb"))
  local code = f:read("*a")
  f:close()
  local ok, err = compile(code, "@" .. arg[i + 1])
  if not ok then
    io.write((tostring(err):gsub("[\r\n]+", " ")), "\n")
  end
end
LUA
  ) || die "the Lua syntax check could not run with $lua_tool (set AF_LUA=none to skip it)"
  while IFS= read -r l; do
    [ -z "$l" ] || problem "Lua syntax error: $l"
  done <<< "$syntax_out"
fi

if [ ${#errors[@]} -gt 0 ]; then
  for e in "${errors[@]}"; do
    printf 'sync: error: %s\n' "$e" >&2
  done
  printf 'sync: found %d problem(s); nothing was installed. Fix them and run sync again.\n' "${#errors[@]}" >&2
  exit 1
fi

# Build the Bundle ------------------------------------------------------------------
# Built before anything in the AddOns folder changes, so a failure leaves the
# previous install untouched.

tmp=$(mktemp "${TMPDIR:-/tmp}/addons-forever-bundle.XXXXXX")
trap 'rm -f "$tmp"' EXIT

{
  printf -- '-- Generated by sync.sh from your addons. Do not edit: it is overwritten on every sync.\n'
  for ((m = 0; m < ${#mod_ids[@]}; m++)); do
    lua_quote "${mod_ids[$m]}"; qid=$REPLY
    lua_quote "${mod_titles[$m]}"; qtitle=$REPLY
    lua_quote "${mod_notes[$m]}"; qnotes=$REPLY
    printf '\n-- Module: %s\n' "${mod_ids[$m]}"
    printf 'AddonsForever:_RegisterModule(%s, { title = %s, notes = %s }, {\n' "$qid" "$qtitle" "$qnotes"
    for ((k = mod_first[m]; k < mod_first[m] + mod_nfiles[m]; k++)); do
      read_file "${file_src[$k]}"; code=$REPLY
      long_level "$code"; eq=$REPLY
      lua_quote "${file_chunk[$k]}"
      printf '  { path = %s, code = [%s[\n' "$REPLY" "$eq"
      printf '%s' "$code"
      case "$code" in ""|*"$NL") ;; *) printf '\n' ;; esac
      printf ']%s] },\n' "$eq"
    done
    printf '})\n'
  done
} > "$tmp"

# Install the Host and Bundle -----------------------------------------------------

mkdir -p "$dest"
cp -R "$HOST_DIR"/. "$dest"/
cp "$tmp" "$dest/.Bundle.lua.new"
mv -f "$dest/.Bundle.lua.new" "$dest/Bundle.lua"

if [ ${#mod_ids[@]} -eq 0 ]; then
  note "no addons found in $MODULES_DIR; installed the Host with an empty Bundle."
else
  note "synced ${#mod_ids[@]} addon(s) into $dest"
fi
note "type /reload in game to load the changes."
