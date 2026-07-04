# Command Tower WezTerm Config

Modular WezTerm configuration optimized for AI agentic development and the hybrid agent mesh.

## Features

- **Modular layout**: config split into focused Lua modules (`appearance`, `domains`, `keys`, `ai_tools`, `workspaces`, `status`, `utils`).
- **AI tool launchers**: `LEADER a` opens a one-shot menu for detected tools (Kimi, Aider, Codex, Claude, Claude Code).
- **Agent session layouts**: `LEADER A` spawns a 3-pane layout (editor | AI tool | lazygit/log watcher).
- **Remote agent swarms**: `LEADER Shift J` teleports to `/mnt/agent-swarms/<task>` on the current domain; `SUPER Shift J` always uses Contabo-VPS.
- **Task ID history**: Swarm Task IDs are remembered and offered as defaults across prompts.
- **Smart splits**: `LEADER |` and `LEADER -` clone the current pane's working directory.
- **Pane marks**: `LEADER m <a-z>` to mark, `LEADER '` to jump.
- **Domain management**: `LEADER d` switches domains; `LEADER D` spawns a tab on a chosen domain mirroring cwd.
- **EternalTerminal launchers**: `LEADER e` picks a predefined host and opens ET + Tmux in a new tab; `LEADER E` prompts for a custom host.
- **Mosh launchers**: `LEADER m` picks a predefined host and opens Mosh + Tmux in a new tab; `LEADER M` prompts for a custom host.
- **Status line**: git branch, `AGENT_TASK_ID`, battery warning, and dev-plane node health.
- **Power/performance**: WebGPU frontend, large scrollback, idle FPS throttling, battery-aware FPS.
- **Session persistence**: `LEADER W s` / `LEADER W r` save and restore lightweight layouts.

## Leader key

The leader is `CTRL + Space`.

## Installation

```bash
ln -sfn ~/wezterm-config ~/.config/wezterm
```

## Environment variables

- `WEZTERM_GITHUB_REPO` — repo used by `#123` and commit-SHA hyperlink rules (default: `dporkka/command-tower-wezterm`).
- `WEZTERM_JIRA_HOST` — Jira host for `PROJECT-123` hyperlink rules (disabled if unset).
- `AGENT_TASK_ID` — displayed in the status line when set.

## Tool detection

AI tools are discovered automatically from `PATH` plus `~/.kimi-code/bin`, `~/.cargo/bin`, `~/.local/bin`, and uv tool directories. Install a tool and reload WezTerm (`LEADER R`) to see it appear.
