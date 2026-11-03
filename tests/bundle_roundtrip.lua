-- Loads a Bundle outside the game and checks that every embedded file's code
-- matches its Module source exactly (ignoring an added final newline).
-- Usage: lua bundle_roundtrip.lua BUNDLE MODULES_DIR

local bundlePath, modulesDir = arg[1], arg[2]

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local ok = true
AddonsForever = {
  _RegisterModule = function(_, id, _, files)
    for _, file in ipairs(files) do
      local rel = file.path:gsub("^modules/", "")
      local src = read(modulesDir .. "/" .. rel)
      if src:sub(-1) ~= "\n" then src = src .. "\n" end
      if file.code ~= src then
        io.stderr:write("mismatch in " .. file.path .. "\n")
        ok = false
      end
    end
  end,
}

local chunk = assert((loadstring or load)(read(bundlePath), "@" .. bundlePath))
chunk()
os.exit(ok and 0 or 1)
