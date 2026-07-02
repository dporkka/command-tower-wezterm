-- keys.lua -- Keybindings for panes, tabs, windows, clipboard, marks, and hyperlinks.

local wezterm = require("wezterm")
local act = wezterm.action
local utils = require("utils")

local M = {}

-- Pane marks stored in memory for the current WezTerm process.
local pane_marks = {}

function M.apply(config)
  config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

  -- Resize mode: leader + r, then h/j/k/l to resize, Esc/Enter/q to exit.
  config.key_tables = config.key_tables or {}
  config.key_tables.resize_pane = {
    { key = "h", action = act.AdjustPaneSize({ "Left", 2 }) },
    { key = "j", action = act.AdjustPaneSize({ "Down", 2 }) },
    { key = "k", action = act.AdjustPaneSize({ "Up", 2 }) },
    { key = "l", action = act.AdjustPaneSize({ "Right", 2 }) },
    { key = "Escape", action = "PopKeyTable" },
    { key = "q", action = "PopKeyTable" },
    { key = "Enter", action = "PopKeyTable" },
  }

  -- Smart split helpers that clone the current pane's cwd.
  local function smart_split(direction)
    return wezterm.action_callback(function(window, pane)
      local cwd = utils.cwd_of(pane)
      pane:split({
        direction = direction,
        size = { Percent = 50 },
        cwd = cwd,
        domain = { DomainName = pane:get_domain_name() },
      })
    end)
  end

  -- Pane mark helpers.
  local function set_mark(label)
    return wezterm.action_callback(function(window, pane)
      pane_marks[label] = pane:pane_id()
      pcall(function()
        window:toast_notification("Pane Mark", "Mark '" .. label .. "' set", nil, 1500)
      end)
    end)
  end

  local function jump_to_mark()
    return wezterm.action_callback(function(window, pane)
      window:perform_action(
        act.PromptInputLine({
          description = "Jump to mark (a-z)",
          action = wezterm.action_callback(function(inner_window, inner_pane, line)
            if not line or #line ~= 1 then
              return
            end
            local pane_id = pane_marks[line]
            if pane_id then
              inner_window:perform_action(act.ActivatePaneById(pane_id), inner_pane)
            else
              pcall(function()
                inner_window:toast_notification("Pane Mark", "No mark '" .. line .. "' set", nil, 1500)
              end)
            end
          end),
        }),
        pane
      )
    end)
  end

  -- Spawn a new tab on a chosen domain, mirroring the current pane's cwd.
  local function spawn_on_domain_with_cwd()
    return wezterm.action_callback(function(window, pane)
      local cwd = utils.cwd_of(pane)
      window:perform_action(
        act.PromptInputLine({
          description = "Domain (local, wsl2, mini-pc, contabo-vps)",
          action = wezterm.action_callback(function(inner_window, inner_pane, line)
            if not line or line == "" then
              return
            end
            inner_window:perform_action(
              act.SpawnCommandInNewTab({
                domain = { DomainName = line },
                cwd = cwd,
                args = { os.getenv("SHELL") or "/bin/bash" },
              }),
              inner_pane
            )
          end),
        }),
        pane
      )
    end)
  end

  config.keys = {
    -- Leader keymaps: tabs, panes, and windows.
    { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "x", mods = "LEADER", action = act.CloseCurrentTab({ confirm = true }) },
    { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
    { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
    { key = "|", mods = "LEADER", action = smart_split("Right") },
    { key = "-", mods = "LEADER", action = smart_split("Bottom") },
    { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
    { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
    { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
    { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
    { key = "w", mods = "LEADER", action = act.SpawnWindow },
    { key = "r", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },
    { key = "R", mods = "LEADER", action = act.ReloadConfiguration },
    { key = "q", mods = "LEADER", action = act.QuitApplication },

    -- Domain switcher.
    { key = "d", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "DOMAINS" }) },
    -- Spawn tab on domain with cwd mirror.
    { key = "D", mods = "LEADER", action = spawn_on_domain_with_cwd() },

    -- Scrollback management.
    { key = "K", mods = "LEADER", action = act.ClearScrollback("ScrollbackAndViewport") },

    -- Search / quick select.
    { key = "f", mods = "LEADER", action = act.Search("CurrentSelectionOrEmptyString") },
    { key = "s", mods = "LEADER", action = act.QuickSelect },

    -- Command palette.
    { key = "P", mods = "LEADER", action = act.ActivateCommandPalette },

    -- Pane mark jump.
    { key = "'", mods = "LEADER", action = jump_to_mark() },

    -- Clipboard (OSC 52 keeps the Windows host clipboard hydrated from yanks).
    { key = "c", mods = "CMD", action = act.CopyTo("ClipboardAndPrimarySelection") },
    { key = "v", mods = "CMD", action = act.PasteFrom("Clipboard") },
  }

  -- Pane marks: LEADER m [a-z].
  config.key_tables.set_mark = {
    { key = "Escape", action = "PopKeyTable" },
    { key = "q", action = "PopKeyTable" },
  }
  for char = string.byte("a"), string.byte("z") do
    local label = string.char(char)
    table.insert(config.key_tables.set_mark, {
      key = label,
      action = set_mark(label),
    })
  end

  table.insert(config.keys, {
    key = "m",
    mods = "LEADER",
    action = act.ActivateKeyTable({ name = "set_mark", one_shot = true, timeout_milliseconds = 1500 }),
  })

  -- Default hyperlink rules + custom ones for agent output.
  -- GitHub repo is configurable via WEZTERM_GITHUB_REPO; defaults to this config repo.
  local github_repo = os.getenv("WEZTERM_GITHUB_REPO") or "dporkka/command-tower-wezterm"
  config.hyperlink_rules = wezterm.default_hyperlink_rules()
  -- GitHub issue/PR references like #123
  table.insert(config.hyperlink_rules, {
    regex = [[#(\d+)]],
    format = "https://github.com/" .. github_repo .. "/issues/$1",
  })
  -- Git commit SHAs
  table.insert(config.hyperlink_rules, {
    regex = [[\b([a-f0-9]{7,40})\b]],
    format = "https://github.com/" .. github_repo .. "/commit/$1",
  })
  -- Jira-style tickets (enabled only when WEZTERM_JIRA_HOST is set).
  local jira_host = os.getenv("WEZTERM_JIRA_HOST")
  if jira_host then
    table.insert(config.hyperlink_rules, {
      regex = [[\b([A-Z][A-Z0-9]+-\d+)\b]],
      format = "https://" .. jira_host .. "/browse/$1",
    })
  end

  -- Mouse: middle-click pastes primary selection.
  config.mouse_bindings = {
    {
      event = { Down = { streak = 1, button = "Middle" } },
      mods = "NONE",
      action = act.PasteFrom("PrimarySelection"),
    },
  }

  -- OSC 52 / advanced input settings.
  config.enable_wayland = true
  config.enable_csi_u_key_encoding = true
  config.allow_win32_input_mode = false
end

return M
