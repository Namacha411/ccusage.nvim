---@class CCUsageModule
local M = {}

local config = {}
local cache = {
  data = nil,
  last_update = 0,
  timer = nil,
  last_error = nil,
}

local function debug_log(msg)
  if config.debug then
    print("[ccusage.nvim] " .. msg)
  end
end

local function format_cost(cost)
  if not cost then return "N/A" end
  local decimal_places = config.decimal_places or 4
  return string.format("$%." .. decimal_places .. "f", cost)
end

local function format_tokens(tokens)
  if not tokens then return "N/A" end
  if tokens >= 1000000 then
    return string.format("%.1fM", tokens / 1000000)
  elseif tokens >= 1000 then
    return string.format("%.1fK", tokens / 1000)
  else
    return tostring(tokens)
  end
end

local function parse_ccusage_output(output)
  debug_log("Parsing ccusage output, length: " .. #output)
  debug_log("Raw output: " .. output)
  
  local ok, data = pcall(vim.json.decode, output)
  if not ok then
    debug_log("JSON decode failed: " .. tostring(data))
    cache.last_error = "JSON decode failed: " .. tostring(data)
    return nil
  end
  
  if not data then
    debug_log("JSON decode returned nil")
    cache.last_error = "JSON decode returned nil"
    return nil
  end
  
  debug_log("JSON decoded successfully, type: " .. type(data))
  debug_log("Data keys: " .. vim.inspect(vim.tbl_keys(data)))
  
  if data.summary then
    debug_log("Found summary data")
    debug_log("Summary: " .. vim.inspect(data.summary))
    return {
      cost = data.summary.costUSD,
      total_tokens = data.summary.totalTokens,
      input_tokens = data.summary.inputTokens,
      output_tokens = data.summary.outputTokens,
    }
  elseif data.data and #data.data > 0 then
    debug_log("Found data array with " .. #data.data .. " entries")
    local latest = data.data[#data.data]
    debug_log("Latest entry: " .. vim.inspect(latest))
    return {
      cost = latest.costUSD,
      total_tokens = latest.totalTokens,
      input_tokens = latest.inputTokens,
      output_tokens = latest.outputTokens,
    }
  elseif data.blocks and #data.blocks > 0 then
    debug_log("Found blocks array with " .. #data.blocks .. " entries")
    
    -- Find the most recent active block or the latest non-gap block
    local latest_block = nil
    for i = #data.blocks, 1, -1 do
      local block = data.blocks[i]
      if not block.isGap then
        latest_block = block
        break
      end
    end
    
    if latest_block then
      debug_log("Using block: " .. vim.inspect(latest_block))
      
      -- Calculate total tokens from tokenCounts
      local token_counts = latest_block.tokenCounts or {}
      local total_tokens = latest_block.totalTokens or (
        (token_counts.inputTokens or 0) + 
        (token_counts.outputTokens or 0) + 
        (token_counts.cacheCreationInputTokens or 0) + 
        (token_counts.cacheReadInputTokens or 0)
      )
      
      return {
        cost = latest_block.costUSD,
        total_tokens = total_tokens,
        input_tokens = token_counts.inputTokens or 0,
        output_tokens = token_counts.outputTokens or 0,
      }
    else
      debug_log("No non-gap blocks found")
      cache.last_error = "No non-gap blocks found in ccusage data"
      return nil
    end
  end
  
  debug_log("No valid data structure found (expected 'summary', 'data', or 'blocks')")
  cache.last_error = "No valid data structure found in JSON (expected 'summary', 'data', or 'blocks')"
  return nil
end

local function fetch_ccusage_data(callback)
  local output = {}
  local error_output = {}
  
  debug_log("Starting ccusage command: npx ccusage@latest blocks --json")
  
  local job_id = vim.fn.jobstart({"npx", "ccusage@latest", "blocks", "--json"}, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data, _)
      debug_log("Received stdout data: " .. vim.inspect(data))
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      debug_log("Received stderr data: " .. vim.inspect(data))
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(error_output, line)
          end
        end
      end
    end,
    on_exit = function(_, code, _)
      debug_log("Command exited with code: " .. code)
      debug_log("Output lines: " .. #output)
      debug_log("Error lines: " .. #error_output)
      
      if #error_output > 0 then
        local error_msg = table.concat(error_output, "\n")
        debug_log("Error output: " .. error_msg)
        cache.last_error = "Command stderr: " .. error_msg
      end
      
      if code == 0 then
        if #output > 0 then
          local json_string = table.concat(output, "\n")
          debug_log("Attempting to parse JSON output")
          local parsed = parse_ccusage_output(json_string)
          if parsed then
            debug_log("Successfully parsed ccusage data")
            cache.data = parsed
            cache.last_update = vim.loop.now()
            cache.last_error = nil
            if callback then callback(parsed) end
          else
            debug_log("Failed to parse ccusage data")
          end
        else
          debug_log("Command succeeded but returned no output")
          cache.last_error = "Command succeeded but returned no output"
        end
      else
        debug_log("Command failed with exit code: " .. code)
        cache.last_error = "Command failed with exit code: " .. code
        if #error_output > 0 then
          cache.last_error = cache.last_error .. "\n" .. table.concat(error_output, "\n")
        end
      end
    end,
  })
  
  if job_id == 0 then
    debug_log("Failed to start job")
    cache.last_error = "Failed to start job (command not found or invalid)"
  elseif job_id == -1 then
    debug_log("Invalid job arguments")
    cache.last_error = "Invalid job arguments"
  else
    debug_log("Job started with ID: " .. job_id)
  end
end

local function start_timer()
  if cache.timer then
    cache.timer:stop()
    cache.timer:close()
  end
  
  cache.timer = vim.loop.new_timer()
  cache.timer:start(0, config.update_interval * 1000, function()
    vim.schedule(function()
      fetch_ccusage_data()
    end)
  end)
end

M.setup = function(user_config)
  config = user_config or {}
  
  fetch_ccusage_data()
  start_timer()
end

M.get_status = function()
  return cache.data
end

M.refresh = function()
  fetch_ccusage_data()
end

M.get_lualine_component = function()
  return {
    function()
      if not cache.data then
        return "ccusage: loading..."
      end
      
      if config.display_format == "cost" then
        return "💰 " .. format_cost(cache.data.cost)
      elseif config.display_format == "tokens" then
        return "🔤 " .. format_tokens(cache.data.total_tokens)
      else -- both
        return "💰 " .. format_cost(cache.data.cost) .. " 🔤 " .. format_tokens(cache.data.total_tokens)
      end
    end,
    cond = function()
      return cache.data ~= nil
    end,
  }
end

M.get_debug_info = function()
  return {
    config = config,
    cache = {
      has_data = cache.data ~= nil,
      data = cache.data,
      last_update = cache.last_update,
      timer_active = cache.timer ~= nil,
      last_error = cache.last_error,
    },
    command = "npx ccusage@latest blocks --json",
  }
end

return M
