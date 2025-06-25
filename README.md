# ccusage.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

A Neovim plugin that displays [ccusage](https://github.com/ryoppippi/ccusage) metrics in your Lualine statusline with automatic refresh every 30 seconds.

## Features

- 🔄 **Auto-refresh**: Updates ccusage data every 30 seconds (configurable)
- 💰 **Cost Display**: Shows Claude API usage costs in real-time
- 🔤 **Token Metrics**: Displays token consumption with smart formatting (K/M suffixes)
- 📊 **Projection Display**: Shows estimated total cost and remaining time for active blocks
- 🔥 **Burn Rate**: Displays cost per hour consumption rate
- 🔴 **Active Indicator**: Visual indicator for currently active usage blocks
- ⚙️ **Multiple Display Formats**: 5 different display modes (cost, tokens, both, projection, burnrate)
- 📊 **Lualine Integration**: Seamless integration with your statusline
- 🎛️ **Manual Controls**: Commands for manual refresh, status checking, and debugging
- 🧠 **Smart Parsing**: Handles multiple JSON objects and finds the most recent active data

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  "Namacha411/ccusage.nvim",
  opts = {},
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "Namacha411/ccusage.nvim",
  config = function()
    require("ccusage").setup()
  end,
}
```

## Prerequisites

- [ccusage](https://github.com/ryoppippi/ccusage) must be available via `npx ccusage@latest`
- Neovim 0.5+
- [Lualine](https://github.com/nvim-lualine/lualine.nvim) (for statusline integration)

## Configuration

```lua
require("ccusage").setup({
  update_interval = 30,           -- Update interval in seconds (default: 30)
  display_format = "cost",        -- Display format (see options below)
  decimal_places = 4,             -- Decimal places for cost display (default: 4)
  debug = false,                  -- Enable debug logging (default: false)
  show_active_indicator = true,   -- Show 🔴 for active blocks (default: true)
})
```

### Display Format Options

| Format | Example | Description |
|--------|---------|-------------|
| `"cost"` | `🔴 💰 $2.64` | Current cost with active indicator |
| `"tokens"` | `🔴 🔤 25.9K` | Token count with smart formatting |
| `"both"` | `🔴 💰 $2.64 🔤 25.9K` | Both cost and tokens |
| `"projection"` | `🔴 📊 $6.12 (140m)` | Projected total cost and remaining time |
| `"burnrate"` | `🔴 🔥 $1.49/h` | Cost consumption rate per hour |

> **Note**: The 🔴 active indicator only appears for currently active usage blocks

## Lualine Integration

Add the ccusage component to your Lualine configuration:

```lua
require("lualine").setup({
  sections = {
    lualine_x = { 
      require("ccusage").get_lualine_component(),
      -- your other components...
    },
  }
})
```

## Advanced Usage

### Real-time Projection Tracking
For active coding sessions, use projection mode to see estimated costs:

```lua
require("ccusage").setup({
  display_format = "projection",  -- 📊 $6.12 (140m) - projected total with time remaining
  update_interval = 15,           -- More frequent updates for active sessions
})
```

### Burn Rate Monitoring
Monitor your API consumption rate:

```lua
require("ccusage").setup({
  display_format = "burnrate",    -- 🔥 $1.49/h - cost per hour
})
```

## Commands

- `:CCUsageRefresh` - Manually refresh ccusage data
- `:CCUsageStatus` - Display current ccusage status in command line
- `:CCUsageDebug` - Show detailed diagnostic information (cache, config, errors)
- `:CCUsageTest` - Test ccusage command execution manually

## API

```lua
local ccusage = require("ccusage")

-- Get current status data
local status = ccusage.get_status()
-- Returns: {
--   cost = 2.6438,
--   total_tokens = 25869,
--   input_tokens = 8952,
--   output_tokens = 16917,
--   is_active = true,
--   burn_rate = { tokensPerMinute = 242.56, costPerHour = 1.487 },
--   projection = { totalTokens = 59840, totalCost = 6.12, remainingMinutes = 140 },
--   block_id = "2025-06-25T12:00:00.000Z"
-- }

-- Manually refresh data
ccusage.refresh()

-- Get Lualine component
local component = ccusage.get_lualine_component()

-- Get debug information
local debug_info = ccusage.get_debug_info()
```

## How it Works

The plugin executes `npx ccusage@latest blocks --json` to fetch current Claude API usage data, intelligently parses multiple JSON objects in the response, and displays the most recent active block metrics in your statusline. Data is automatically refreshed every 30 seconds (configurable) and cached for performance.

### Smart Data Selection
- **Multi-JSON Parsing**: Handles multiple JSON objects in ccusage output
- **Active Block Priority**: Prioritizes currently active usage blocks
- **Timestamp Comparison**: Finds the most recent data across all blocks
- **Gap Filtering**: Automatically skips inactive gap periods

## Troubleshooting

### Debug Mode
Enable debug logging to troubleshoot issues:

```lua
require("ccusage").setup({ debug = true })
```

Then use `:CCUsageDebug` to see detailed information about:
- Configuration settings
- Cache status and data
- Last update time and errors
- Raw JSON parsing results

### Common Issues
- **"No data available"**: Run `:CCUsageTest` to check if ccusage command works
- **Empty display**: Ensure ccusage is configured with valid Claude API credentials
- **Parsing errors**: Check `:CCUsageDebug` for JSON structure issues

## Requirements

- Neovim 0.5+
- Node.js (for npx)
- [ccusage](https://github.com/ryoppippi/ccusage) CLI tool
