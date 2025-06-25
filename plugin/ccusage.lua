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

vim.api.nvim_create_user_command("CCUsageDebug", function()
  local debug_info = require("ccusage").get_debug_info()
  print("=== CCUsage Debug Information ===")
  print("Command: " .. debug_info.command)
  print("Config: " .. vim.inspect(debug_info.config))
  print("Cache has data: " .. tostring(debug_info.cache.has_data))
  print("Timer active: " .. tostring(debug_info.cache.timer_active))
  if debug_info.cache.last_update > 0 then
    print("Last update: " .. os.date("%Y-%m-%d %H:%M:%S", debug_info.cache.last_update / 1000))
  else
    print("Last update: Never")
  end
  if debug_info.cache.last_error then
    print("Last error: " .. debug_info.cache.last_error)
  else
    print("Last error: None")
  end
  if debug_info.cache.data then
    print("Data: " .. vim.inspect(debug_info.cache.data))
  else
    print("Data: None")
  end
  print("=== End Debug Information ===")
end, {
  desc = "Show detailed ccusage debug information"
})

vim.api.nvim_create_user_command("CCUsageTest", function()
  print("Testing ccusage command manually...")
  local output = {}
  local error_output = {}
  
  local job_id = vim.fn.jobstart({"npx", "ccusage@latest", "blocks", "--json"}, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(error_output, line)
          end
        end
      end
    end,
    on_exit = function(_, code, _)
      print("=== CCUsage Command Test Results ===")
      print("Exit code: " .. code)
      print("Output lines: " .. #output)
      print("Error lines: " .. #error_output)
      
      if #error_output > 0 then
        print("Stderr:")
        for _, line in ipairs(error_output) do
          print("  " .. line)
        end
      end
      
      if #output > 0 then
        print("Stdout:")
        for _, line in ipairs(output) do
          print("  " .. line)
        end
      else
        print("No stdout output")
      end
      print("=== End Test Results ===")
    end,
  })
  
  if job_id == 0 then
    print("Failed to start job (command not found)")
  elseif job_id == -1 then
    print("Invalid job arguments")
  else
    print("Job started with ID: " .. job_id)
  end
end, {
  desc = "Test ccusage command execution manually"
})
