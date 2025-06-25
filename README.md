# ccusage.nvim

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

A Neovim plugin that displays [ccusage](https://github.com/ryoppippi/ccusage) metrics in your Lualine statusline with automatic refresh every 30 seconds.

## Features

- 🔄 **Auto-refresh**: Updates ccusage data every 30 seconds (configurable)
- 💰 **Cost Display**: Shows Claude API usage costs in real-time
- 🔤 **Token Metrics**: Displays token consumption with smart formatting (K/M suffixes)
- ⚙️ **Configurable**: Multiple display formats and update intervals
- 📊 **Lualine Integration**: Seamless integration with your statusline
- 🎛️ **Manual Controls**: Commands for manual refresh and status checking

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
  update_interval = 30,        -- Update interval in seconds (default: 30)
  display_format = "cost",     -- Display format: "cost" | "tokens" | "both" (default: "cost")
  decimal_places = 4,          -- Decimal places for cost display (default: 4)
})
```

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

## Display Formats

- **`"cost"`**: Shows only cost with 💰 icon (e.g., "💰 $0.0125")
- **`"tokens"`**: Shows only tokens with 🔤 icon (e.g., "🔤 15.2K")  
- **`"both"`**: Shows both cost and tokens (e.g., "💰 $0.0125 🔤 15.2K")

## Commands

- `:CCUsageRefresh` - Manually refresh ccusage data
- `:CCUsageStatus` - Display current ccusage status in command line

## API

```lua
local ccusage = require("ccusage")

-- Get current status data
local status = ccusage.get_status()
-- Returns: { cost = 0.0125, total_tokens = 15234, input_tokens = 8456, output_tokens = 6778 }

-- Manually refresh data
ccusage.refresh()

-- Get Lualine component
local component = ccusage.get_lualine_component()
```

## How it Works

The plugin executes `npx ccusage@latest blocks --json` to fetch current Claude API usage data, parses the JSON response, and displays the metrics in your statusline. Data is automatically refreshed every 30 seconds (configurable) and cached for performance.

## Requirements

- Neovim 0.5+
- Node.js (for npx)
- [ccusage](https://github.com/ryoppippi/ccusage) CLI tool
