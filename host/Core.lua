-- Addons Forever Host.
--
-- Loads every Module from the Bundle (written by the sync script) and keeps
-- the Debug Log in the AddonsForeverLog saved variable, which the game writes
-- to disk on /reload, logout or disconnect.
--
-- Load sequence:
--   1. Bundle.lua runs and registers each Module's source with the Host.
--   2. ADDON_LOADED: saved variables are ready; the Debug Log starts a new
--      session and each Module's files are compiled and run.
--   3. PLAYER_LOGIN (also fires after /reload): each loaded Module's OnEnable
--      is called.

local HOST_NAME = ...

local AF = {}
_G.AddonsForever = AF

local pending = {}  -- registrations from the Bundle, in load order
local modules = {}  -- id -> Module
local order = {}    -- Module ids in load order
local loading       -- the Module whose files are currently running

-- Debug Log ------------------------------------------------------------------

local log           -- AddonsForeverLog once saved variables have loaded
local buffer = {}   -- entries recorded before that

local function echo(source, msg, level)
  if DEFAULT_CHAT_FRAME then
    local colour = level == "error" and "ffff5555" or "ff33ff99"
    DEFAULT_CHAT_FRAME:AddMessage(("|c%sAddons Forever|r [%s] %s"):format(colour, source or "Host", msg))
  end
end

local function record(entry)
  entry.time = entry.time or time()
  if log then
    table.insert(log.entries, entry)
  else
    table.insert(buffer, entry)
  end
end

local function addEntry(level, moduleId, msg)
  record({ level = level, module = moduleId, msg = msg })
  echo(moduleId, msg, level)
end

local function startSession()
  AddonsForeverLog = AddonsForeverLog or {}
  log = AddonsForeverLog
  log.entries = log.entries or {}

  local version, build, _, interface = GetBuildInfo()
  local session = {
    kind = "session",
    level = "info",
    version = version,
    build = build,
    interface = interface,
    msg = ("Session start: WoW %s (build %s, interface %s)"):format(
      tostring(version), tostring(build), tostring(interface)),
  }
  record(session)
  log.lastSession = { version = version, build = build, interface = interface, time = session.time }

  for _, entry in ipairs(buffer) do
    table.insert(log.entries, entry)
  end
  buffer = {}
end

-- Modules --------------------------------------------------------------------

local Module = {}
Module.__index = Module

-- Writes a line to the Debug Log (and chat). Arguments are joined like print().
function Module:Log(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring((select(i, ...)))
  end
  addEntry("info", self.id, table.concat(parts, " "))
end

-- Called at the top of a Module's code; returns that Module's object.
function AF:NewModule(id)
  if not loading then
    error("AddonsForever:NewModule must be called from a Module's own files", 2)
  end
  if id ~= loading.id then
    error(("AddonsForever:NewModule(%q) called inside Module %q; the id must match the Module's folder name")
      :format(tostring(id), loading.id), 2)
  end
  return loading
end

-- Called by the Bundle. files is a list of { path = ..., code = ... }.
function AF:_RegisterModule(id, meta, files)
  table.insert(pending, { id = id, meta = meta, files = files })
end

local function loadModule(reg)
  local M = setmetatable({ id = reg.id, title = reg.meta.title or reg.id, status = "loading" }, Module)
  modules[reg.id] = M
  table.insert(order, reg.id)

  loading = M
  for _, file in ipairs(reg.files) do
    local chunk, err = loadstring(file.code, "@" .. file.path)
    if chunk then
      local ok, runErr = pcall(chunk, reg.id, M)
      if not ok then
        err = runErr or "unknown error"
      end
    end
    if err then
      M.status = "failed"
      addEntry("error", reg.id, "Failed to load: " .. tostring(err))
      break
    end
  end
  loading = nil

  if M.status == "loading" then
    M.status = "loaded"
  end
end

local function enableModules()
  for _, id in ipairs(order) do
    local M = modules[id]
    if M.status == "loaded" and type(M.OnEnable) == "function" then
      local ok, err = pcall(M.OnEnable, M)
      if not ok then
        M.status = "failed"
        addEntry("error", id, "OnEnable failed: " .. tostring(err))
      end
    end
  end
end

-- Events ---------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == HOST_NAME then
    AddonsForeverDB = AddonsForeverDB or {}
    AddonsForeverCharDB = AddonsForeverCharDB or {}
    startSession()
    for _, reg in ipairs(pending) do
      loadModule(reg)
    end
    pending = {}
  elseif event == "PLAYER_LOGIN" then
    enableModules()
  end
end)
