-- workspaces.lua -- Named startup layouts and lightweight session persistence.

local wezterm = require("wezterm")
local act = wezterm.action
local utils = require("utils")

local M = {}

local SESSIONS_FILE = (os.getenv("HOME") or "/tmp") .. "/.cache/dev-plane/wezterm-sessions.json"

-- Spawn a 2-pane workspace: left = editor, right = shell command.
local function spawn_editor_plus_shell(opts)
  return wezterm.action_callback(function(window, pane)
    local cwd = opts.cwd
    local domain = opts.domain or "CurrentPaneDomain"
    local right_cmd = opts.right_cmd or { os.getenv("SHELL") or "/bin/bash" }

    -- Left pane opens the editor.
    if cwd then
      pane:send_text("cd " .. cwd:gsub(" ", "\\ ") .. "\n")
    end
    pane:send_text("nvim .\n")

    -- Right pane runs the supplied command.
    pane:split({
      direction = "Right",
      size = { Percent = 50 },
      domain = domain,
      cwd = cwd,
      args = right_cmd,
    })
  end)
end

-- Save the current window's tabs/panes/cwds/domains to a JSON file.
local function save_session(name)
  return wezterm.action_callback(function(window, pane)
    local tabs = window:tabs()
    local session = { tabs = {} }
    for _, tab in ipairs(tabs) do
      local tab_info = { panes = {} }
      for _, p in ipairs(tab:panes()) do
        table.insert(tab_info.panes, {
          domain = p:get_domain_name(),
          cwd = utils.cwd_of(p),
          title = p:get_title(),
        })
      end
      table.insert(session.tabs, tab_info)
    end
    local sessions = utils.read_json(SESSIONS_FILE) or {}
    sessions[name] = session
    utils.write_json(SESSIONS_FILE, sessions)
    pcall(function()
      window:toast_notification("Session", "Saved '" .. name .. "'", nil, 1500)
    end)
  end)
end

-- Restore a simple two-pane session into the current window.
local function restore_session(name)
  return wezterm.action_callback(function(window, pane)
    local sessions = utils.read_json(SESSIONS_FILE) or {}
    local session = sessions[name]
    if not session then
      pcall(function()
        window:toast_notification("Session", "No session named '" .. name .. "'", nil, 1500)
      end)
      return
    end

    local first_tab = session.tabs[1]
    if not first_tab then
      return
    end

    -- Restore cwd of the first pane.
    local first_pane = first_tab.panes[1]
    if first_pane and first_pane.cwd then
      pane:send_text("cd " .. first_pane.cwd:gsub(" ", "\\ ") .. "\n")
    end

    -- Restore a second pane if it existed.
    if #first_tab.panes > 1 then
      local second = first_tab.panes[2]
      pane:split({
        direction = "Right",
        size = { Percent = 50 },
        domain = { DomainName = second.domain or "CurrentPaneDomain" },
        cwd = second.cwd,
        args = { os.getenv("SHELL") or "/bin/bash" },
      })
    end

    pcall(function()
      window:toast_notification("Session", "Restored '" .. name .. "'", nil, 1500)
    end)
  end)
end

function M.apply(config)
  -- Workspace launcher under LEADER + w.
  config.key_tables = config.key_tables or {}
  config.key_tables.workspaces = {
    {
      key = "c",
      action = spawn_editor_plus_shell({
        cwd = wezterm.home_dir .. "/dev-plane",
        right_cmd = utils.which("kimi") and { "kimi" } or { os.getenv("SHELL") or "/bin/bash" },
      }),
    },
    {
      key = "v",
      action = wezterm.action_callback(function(window, pane)
        local recent = utils.most_recent_task_id()
        local prompt_text = "Swarm Task ID (remote VPS workspace)"
        if recent then
          prompt_text = prompt_text .. " [default: " .. recent .. "]"
        end
        window:perform_action(
          act.PromptInputLine({
            description = prompt_text,
            action = wezterm.action_callback(function(inner_window, inner_pane, line)
              local task_id = line
              if not task_id or task_id == "" then
                task_id = recent
              end
              if not task_id or task_id == "" then
                return
              end
              task_id = task_id:gsub("^%s*(.-)%s*$", "%1")
              utils.push_task_id(task_id)
              local remote_path = "/mnt/agent-swarms/" .. task_id
              inner_window:perform_action(
                act.SpawnCommandInNewWindow({
                  domain = { DomainName = "contabo-vps" },
                  cwd = remote_path,
                  args = { "nvim", "." },
                }),
                inner_pane
              )
            end),
          }),
          pane
        )
      end),
    },
    {
      key = "d",
      action = wezterm.action_callback(function(window, pane)
        local cwd = wezterm.home_dir .. "/dev-plane"
        pane:send_text("cd " .. cwd:gsub(" ", "\\ ") .. "\n")
        local bv_cmd = utils.which("bv") and "bv" or "echo 'Beads Viewer (bv) not on PATH'"
        pane:send_text(bv_cmd .. " workspace open local/command-tower\n")
      end),
    },
    { key = "Escape", action = "PopKeyTable" },
    { key = "q", action = "PopKeyTable" },
  }

  -- Session save/restore key table.
  config.key_tables.sessions = {
    {
      key = "s",
      action = wezterm.action_callback(function(window, pane)
        window:perform_action(
          act.PromptInputLine({
            description = "Save session as",
            action = wezterm.action_callback(function(inner_window, inner_pane, line)
              if line and line ~= "" then
                inner_window:perform_action(save_session(line), inner_pane)
              end
            end),
          }),
          pane
        )
      end),
    },
    {
      key = "r",
      action = wezterm.action_callback(function(window, pane)
        local sessions = utils.read_json(SESSIONS_FILE) or {}
        local names = {}
        for name, _ in pairs(sessions) do
          table.insert(names, name)
        end
        table.sort(names)
        window:perform_action(
          act.PromptInputLine({
            description = "Restore session (" .. table.concat(names, ", ") .. ")",
            action = wezterm.action_callback(function(inner_window, inner_pane, line)
              if line and line ~= "" then
                inner_window:perform_action(restore_session(line), inner_pane)
              end
            end),
          }),
          pane
        )
      end),
    },
    { key = "Escape", action = "PopKeyTable" },
    { key = "q", action = "PopKeyTable" },
  }

  table.insert(config.keys, {
    key = "w",
    mods = "LEADER",
    action = act.ActivateKeyTable({ name = "workspaces", one_shot = true, timeout_milliseconds = 3000 }),
  })

  table.insert(config.keys, {
    key = "W",
    mods = "LEADER",
    action = act.ActivateKeyTable({ name = "sessions", one_shot = true, timeout_milliseconds = 3000 }),
  })
end

return M
