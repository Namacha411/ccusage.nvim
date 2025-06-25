---@class CCUsageModule
local M = {}

local config = {}
local cache = {
  data = nil,
  last_update = 0,
  timer = nil,
}

local function format_cost(cost)
  if not cost then return "N/A" end
  return string.format("$%.4f", cost)
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
  local ok, data = pcall(vim.json.decode, output)
  if not ok or not data then
    return nil
  end
  
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
  end
  
  return nil
end

local function fetch_ccusage_data(callback)
  local output = {}
  
  vim.fn.jobstart({"npx", "ccusage@latest", "blocks", "--json"}, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output, line)
          end
        end
      end
    end,
    on_exit = function(_, code, _)
      if code == 0 and #output > 0 then
        local json_string = table.concat(output, "\n")
        local parsed = parse_ccusage_output(json_string)
        if parsed then
          cache.data = parsed
          cache.last_update = vim.loop.now()
          if callback then callback(parsed) end
        end
      end
    end,
  })
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

return M
