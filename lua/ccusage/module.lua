---@class CCUsageModule
local M = {}

local config = {}
local cache = {
  data = nil,
  last_update = 0,
  timer = nil,
  last_error = nil,
}

local function format_cost(cost)
  if not cost then
    return "N/A"
  end
  local decimal_places = config.decimal_places or 2
  return string.format("$%." .. decimal_places .. "f", cost)
end

local function format_tokens(tokens)
  if not tokens then
    return "N/A"
  end
  if tokens >= 1000000 then
    return string.format("%.1fM", tokens / 1000000)
  elseif tokens >= 1000 then
    return string.format("%.1fK", tokens / 1000)
  else
    return tostring(tokens)
  end
end

local function parse_ccusage_output(output)
  -- Handle multiple JSON objects (split by newlines and parse each)
  local json_objects = {}
  local lines = vim.split(output, "\n")
  local current_json = ""
  local brace_count = 0

  for _, line in ipairs(lines) do
    if line:match("^%s*{") or brace_count > 0 then
      current_json = current_json .. line .. "\n"

      -- Count braces to determine when JSON object is complete
      for char in line:gmatch(".") do
        if char == "{" then
          brace_count = brace_count + 1
        elseif char == "}" then
          brace_count = brace_count - 1
        end
      end

      -- When brace count reaches 0, we have a complete JSON object
      if brace_count == 0 and current_json:match("%S") then
        local ok, data = pcall(vim.json.decode, current_json)
        if ok and data then
          table.insert(json_objects, data)
        end
        current_json = ""
      end
    end
  end

  -- If no multiple objects found, try parsing the entire output as one JSON
  if #json_objects == 0 then
    local ok, data = pcall(vim.json.decode, output)
    if ok and data then
      table.insert(json_objects, data)
    else
      cache.last_error = "JSON decode failed: " .. tostring(data)
      return nil
    end
  end

  -- Process each JSON object and find the best data
  local best_block = nil
  local best_timestamp = 0

  for _, data in ipairs(json_objects) do
    if data.summary then
      return {
        cost = data.summary.costUSD,
        total_tokens = data.summary.totalTokens,
        input_tokens = data.summary.inputTokens,
        output_tokens = data.summary.outputTokens,
      }
    elseif data.data and #data.data > 0 then
      local latest = data.data[#data.data]
      return {
        cost = latest.costUSD,
        total_tokens = latest.totalTokens,
        input_tokens = latest.inputTokens,
        output_tokens = latest.outputTokens,
      }
    elseif data.blocks and #data.blocks > 0 then
      -- Find the most recent active block or latest non-gap block
      for i = #data.blocks, 1, -1 do
        local block = data.blocks[i]
        if not block.isGap then
          -- Convert timestamp to compare recency
          local timestamp = 0
          if block.actualEndTime then
            timestamp = vim.fn.strptime("%Y-%m-%dT%H:%M:%S", block.actualEndTime:sub(1, 19))
          elseif block.startTime then
            timestamp = vim.fn.strptime("%Y-%m-%dT%H:%M:%S", block.startTime:sub(1, 19))
          end

          if timestamp > best_timestamp then
            best_block = block
            best_timestamp = timestamp
          end
          break -- Use the first (most recent) non-gap block from this object
        end
      end
    end
  end

  if best_block then
    local token_counts = best_block.tokenCounts or {}
    local total_tokens = best_block.totalTokens
      or (
        (token_counts.inputTokens or 0)
        + (token_counts.outputTokens or 0)
        + (token_counts.cacheCreationInputTokens or 0)
        + (token_counts.cacheReadInputTokens or 0)
      )

    return {
      cost = best_block.costUSD,
      total_tokens = total_tokens,
      input_tokens = token_counts.inputTokens or 0,
      output_tokens = token_counts.outputTokens or 0,
      is_active = best_block.isActive,
      burn_rate = best_block.burnRate,
      projection = best_block.projection,
      block_id = best_block.id,
    }
  end

  cache.last_error = "No valid data structure found in JSON (expected 'summary', 'data', or 'blocks')"
  return nil
end

local function fetch_ccusage_data(callback)
  local output = {}
  local error_output = {}

  local job_id = vim.fn.jobstart({ "npx", "ccusage@latest", "blocks", "--json" }, {
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
      if #error_output > 0 then
        local error_msg = table.concat(error_output, "\n")
        cache.last_error = "Command stderr: " .. error_msg
      end

      if code == 0 then
        if #output > 0 then
          local json_string = table.concat(output, "\n")
          local parsed = parse_ccusage_output(json_string)
          if parsed then
            cache.data = parsed
            cache.last_update = vim.loop.now()
            cache.last_error = nil
            if callback then
              callback(parsed)
            end
          end
        else
          cache.last_error = "Command succeeded but returned no output"
        end
      else
        cache.last_error = "Command failed with exit code: " .. code
        if #error_output > 0 then
          cache.last_error = cache.last_error .. "\n" .. table.concat(error_output, "\n")
        end
      end
    end,
  })

  if job_id == 0 then
    cache.last_error = "Failed to start job (command not found or invalid)"
  elseif job_id == -1 then
    cache.last_error = "Invalid job arguments"
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

      local active_indicator = ""
      if config.show_active_indicator and cache.data.is_active then
        active_indicator = "🔴 "
      end

      if config.display_format == "cost" then
        return active_indicator .. "💰 " .. format_cost(cache.data.cost)
      elseif config.display_format == "tokens" then
        return active_indicator .. "🔤 " .. format_tokens(cache.data.total_tokens)
      elseif config.display_format == "both" then
        return active_indicator
          .. "💰 "
          .. format_cost(cache.data.cost)
          .. " 🔤 "
          .. format_tokens(cache.data.total_tokens)
      elseif config.display_format == "projection" and cache.data.projection then
        local proj = cache.data.projection
        return active_indicator
          .. "📊 "
          .. format_tokens(proj.totalTokens)
          .. "Token "
          .. format_cost(proj.totalCost)
          .. " ("
          .. (proj.remainingMinutes or 0)
          .. "m)"
      elseif config.display_format == "burnrate" and cache.data.burn_rate then
        local rate = cache.data.burn_rate
        return active_indicator .. "🔥 " .. format_cost(rate.costPerHour) .. "/h"
      else
        -- Fallback to cost display
        return active_indicator .. "💰 " .. format_cost(cache.data.cost)
      end
    end,
    cond = function()
      return cache.data ~= nil
    end,
  }
end

return M
