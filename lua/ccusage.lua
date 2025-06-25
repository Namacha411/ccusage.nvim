local ccusage = require("ccusage.module")

---@class CCUsageConfig
---@field update_interval number Update interval in seconds (default: 30)
---@field display_format string Display format: "cost" | "tokens" | "both" | "projection" | "burnrate" (default: "cost")
---@field decimal_places number Decimal places for cost display (default: 4)
---@field show_active_indicator boolean Show indicator for active blocks (default: true)
local config = {
  update_interval = 30,
  display_format = "cost",
  decimal_places = 4,
  show_active_indicator = true,
}

---@class CCUsagePlugin
local M = {}

---@type CCUsageConfig
M.config = config

---@param args CCUsageConfig?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
  ccusage.setup(M.config)
end

M.get_status = function()
  return ccusage.get_status()
end

M.refresh = function()
  ccusage.refresh()
end

M.get_lualine_component = function()
  return ccusage.get_lualine_component()
end

return M
