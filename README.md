# nvim-ghostty-theme-sync

Sync your Neovim colorscheme to Ghostty. Generates a custom Ghostty theme file from your current nvim colors and updates the Ghostty config to use it.

## Usage

Run `:GhosttySyncTheme` in Neovim, then Reload Config in Ghostty (`Cmd+Shift+,` on macOS).

## How it works

1. Reads your current nvim highlight groups (Normal, Cursor, Visual, terminal colors, etc.)
2. Generates a Ghostty theme file at the appropriate config directory
3. Updates your Ghostty config to use the generated theme

## Installation

With lazy.nvim:

```lua
{
  "your-username/nvim-ghostty-theme-sync",
  opts = {
    -- Optional: custom Ghostty config path (auto-detected on macOS/Linux)
    -- ghostty_config_path = "~/.config/ghostty/config",
    -- Optional: custom theme name (default: "nvim-synced")
    -- theme_name = "nvim-synced",
  },
}
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ghostty_config_path` | string | auto-detected | Path to Ghostty config file |
| `theme_name` | string | `"nvim-synced"` | Name of the generated theme file |

## Requirements

- Neovim 0.9+
- Ghostty installed
- macOS or Linux

## How the colors map

| Nvim Highlight | Ghostty Color |
|---------------|---------------|
| `Normal` bg | `background` |
| `Normal` fg | `foreground` |
| `Cursor` | `cursor-color` / `cursor-text` |
| `Visual` | `selection-background` / `selection-foreground` |
| `g:terminal_color_0` through `_15` | `palette = 0` through `15` |

If terminal colors are not set by your colorscheme, they are derived from diagnostic/statement highlights.
