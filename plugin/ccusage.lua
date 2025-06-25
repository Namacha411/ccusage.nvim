vim.api.nvim_create_user_command("CCUsageRefresh", require("ccusage").refresh, {
  desc = "Refresh ccusage data manually"
})

vim.api.nvim_create_user_command("CCUsageStatus", function()
  local status = require("ccusage").get_status()
  if status then
    print(string.format("Cost: $%.4f, Tokens: %d", status.cost or 0, status.total_tokens or 0))
  else
    print("CCUsage: No data available")
  end
end, {
  desc = "Show current ccusage status"
})

