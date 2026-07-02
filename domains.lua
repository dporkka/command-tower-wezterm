-- domains.lua -- Multiplexer domain definitions for the agent mesh.

local M = {}

function M.apply(config)
  -- The built-in "local" unix domain is used as the default landing zone.
  -- (We intentionally do not redefine it; "local" is reserved by WezTerm.)

  -- Remote mux servers are reached over Tailscale.
  config.ssh_domains = {
    {
      name = "wsl2",
      remote_address = "100.64.0.2",
    },
    {
      name = "mini-pc",
      remote_address = "100.64.0.3",
    },
    {
      name = "contabo-vps",
      remote_address = "100.64.0.10",
    },
  }

  -- Start the GUI connected to the local mux domain so tabs/windows survive crashes.
  config.default_gui_startup_args = { "connect", "local" }
  config.mux_enable_ssh_agent = false
end

return M
