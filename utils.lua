-- utils.lua -- Shared helpers for the Command Tower WezTerm config.

local wezterm = require("wezterm")

local M = {}

local HOME = os.getenv("HOME") or "/tmp"

-- Safely get the file_path cwd of a pane.
function M.cwd_of(pane)
  local cwd = pane:get_current_working_dir()
  if cwd and cwd.file_path then
    return cwd.file_path
  end
  if type(cwd) == "string" then
    return cwd
  end
  return nil
end

-- Check whether a file exists using glob (avoids io.open for executables).
local function file_exists(path)
  local matches = wezterm.glob(path)
  return matches and #matches > 0
end

M.file_exists = file_exists

-- Resolve an executable name on PATH plus known user bin directories.
function M.which(name)
  local candidates = {
    HOME .. "/.kimi-code/bin/" .. name,
    HOME .. "/.cargo/bin/" .. name,
    HOME .. "/.local/bin/" .. name,
    HOME .. "/bin/" .. name,
  }
  local path_env = os.getenv("PATH") or ""
  for dir in path_env:gmatch("[^:]+") do
    table.insert(candidates, dir .. "/" .. name)
  end
  for _, p in ipairs(candidates) do
    if file_exists(p) then
      return p
    end
  end
  return nil
end

-- Read a JSON file or return nil.
function M.read_json(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local data = f:read("*a")
  f:close()
  if not data or data == "" then
    return nil
  end
  local ok, parsed = pcall(wezterm.json_parse, data)
  if not ok then
    return nil
  end
  return parsed
end

-- Write a value as JSON.
function M.write_json(path, value)
  local dir = path:match("^(.*)/[^/]+$")
  if dir then
    os.execute("mkdir -p " .. dir)
  end
  local f = io.open(path, "w")
  if not f then
    return false
  end
  f:write(wezterm.json_encode(value))
  f:close()
  return true
end

-- Read the current git branch from .git/HEAD without shelling out.
function M.git_branch(cwd)
  if not cwd then
    return nil
  end
  local head_path = cwd .. "/.git/HEAD"
  local f = io.open(head_path, "r")
  if not f then
    return nil
  end
  local head = f:read("*l")
  f:close()
  if not head then
    return nil
  end
  local branch = head:match("ref: refs/heads/(.+)$")
  if branch then
    return branch
  end
  -- Detached HEAD; return short SHA.
  return head:sub(1, 7)
end

-- Return battery state { capacity = number, status = "Charging"|"Discharging"|... } or nil.
function M.battery_status()
  local base = "/sys/class/power_supply/BAT0"
  if not file_exists(base .. "/capacity") then
    return nil
  end
  local cap_f = io.open(base .. "/capacity", "r")
  local status_f = io.open(base .. "/status", "r")
  if not cap_f then
    return nil
  end
  local capacity = tonumber(cap_f:read("*l")) or 0
  cap_f:close()
  local status = status_f and status_f:read("*l") or "Unknown"
  if status_f then
    status_f:close()
  end
  return { capacity = capacity, status = status }
end

-- Map domain names to Catppuccin Mocha colors.
function M.domain_color(domain)
  local colors = {
    ["local"] = "#89b4fa",
    ["wsl2"] = "#a6e3a1",
    ["mini-pc"] = "#f9e2af",
    ["contabo-vps"] = "#f38ba8",
  }
  return colors[domain] or "#cdd6f4"
end

-- Task history helpers.
function M.task_history_path()
  return HOME .. "/.cache/dev-plane/wezterm-task-history.json"
end

function M.load_task_history()
  local history = M.read_json(M.task_history_path())
  if type(history) ~= "table" then
    return {}
  end
  return history
end

function M.save_task_history(history)
  M.write_json(M.task_history_path(), history)
end

function M.push_task_id(id)
  if not id or id == "" then
    return
  end
  local history = M.load_task_history()
  -- Remove existing entry so most-recent is first.
  for i, existing in ipairs(history) do
    if existing == id then
      table.remove(history, i)
      break
    end
  end
  table.insert(history, 1, id)
  -- Keep last 20.
  while #history > 20 do
    table.remove(history)
  end
  M.save_task_history(history)
end

function M.most_recent_task_id()
  local history = M.load_task_history()
  return history[1]
end

return M
