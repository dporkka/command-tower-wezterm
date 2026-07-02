-- appearance.lua -- Visual and rendering settings for agentic work.

local wezterm = require("wezterm")
local utils = require("utils")

local M = {}

function M.apply(config)
  -- Front-end rendering: WebGPU with a 60 FPS cap for smooth but efficient output.
  config.front_end = "WebGpu"
  config.max_fps = 60
  config.animation_fps = 60

  -- Prefer a discrete GPU when available; falls back automatically.
  -- name/backend/device_type are all part of WezTerm's GpuInfo structure.
  config.webgpu_preferred_adapter = {
    name = "",
    backend = "Vulkan",
    device_type = "DiscreteGpu",
  }

  -- Large scrollback for long agent logs and build output.
  config.scrollback_lines = 100000
  config.enable_scroll_bar = true

  -- Color scheme and font.
  -- Use the system "JetBrains Mono" family; WezTerm's built-in Nerd Font symbols
  -- (Symbols Nerd Font Mono) are automatically added as a fallback for glyphs.
  config.color_scheme = "Catppuccin Mocha"
  config.font = wezterm.font("JetBrains Mono", { weight = "Medium" })
  config.font_size = 12.0
  config.line_height = 1.2

  -- Font rendering tweaks for crisp text at small sizes.
  config.freetype_load_target = "Light"
  config.freetype_render_target = "HorizontalLcd"

  -- Window / tab appearance.
  config.window_decorations = "RESIZE"
  config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }
  config.use_fancy_tab_bar = true
  config.tab_bar_at_bottom = true
  config.hide_tab_bar_if_only_one_tab = false
  config.show_new_tab_button_in_tab_bar = true

  -- Inactive pane dimming makes it obvious which pane is receiving input.
  config.inactive_pane_hsb = {
    saturation = 0.85,
    brightness = 0.65,
  }

  -- Enable modern terminal extensions used by TUIs (lazygit, fzf, nvim, etc.).
  config.enable_kitty_graphics = true
  config.enable_kitty_keyboard = true

  -- Visual bell config (audible bell is disabled in status.lua).
  config.visual_bell = {
    fade_in_function = "EaseIn",
    fade_in_duration_ms = 75,
    fade_out_function = "EaseOut",
    fade_out_duration_ms = 75,
  }

  -- Throttle FPS when unfocused.
  wezterm.on("window-focus-lost", function(window, pane)
    window:set_config_overrides({ max_fps = 30 })
  end)

  wezterm.on("window-focus-gained", function(window, pane)
    local battery = utils.battery_status()
    if battery and battery.status == "Discharging" and battery.capacity <= 30 then
      window:set_config_overrides({ max_fps = 30 })
    else
      window:set_config_overrides({ max_fps = 60 })
    end
  end)
end

return M
