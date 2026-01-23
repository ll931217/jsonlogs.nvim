-- Virtual text annotations for log entries
local json = require("jsonlogs.json")
local config = require("jsonlogs.config")

local M = {}

M.namespace = vim.api.nvim_create_namespace("jsonlogs_virtual_text")

-- Parse ISO8601 timestamp to human-readable format
-- @param timestamp string: ISO8601 timestamp
-- @return string: Human-readable time or empty string
local function format_timestamp(timestamp)
  if not timestamp or type(timestamp) ~= "string" then
    return ""
  end

  local year, month, day, hour, min, sec = timestamp:match(
    "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)"
  )

  if not year then
    return ""
  end

  local time = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
  })

  local now = os.time()
  local diff = now - time

  if diff < 60 then
    return string.format("%ds ago", diff)
  elseif diff < 3600 then
    return string.format("%dm ago", math.floor(diff / 60))
  elseif diff < 86400 then
    return string.format("%dh ago", math.floor(diff / 3600))
  else
    return string.format("%dd ago", math.floor(diff / 86400))
  end
end

-- Calculate duration if duration_ms field exists
-- @param duration_ms number: Duration in milliseconds
-- @return string: Formatted duration
local function format_duration(duration_ms)
  if not duration_ms or type(duration_ms) ~= "number" then
    return ""
  end

  if duration_ms < 1000 then
    return string.format("%dms", duration_ms)
  elseif duration_ms < 60000 then
    return string.format("%.1fs", duration_ms / 1000)
  else
    return string.format("%.1fm", duration_ms / 60000)
  end
end

-- Add virtual text annotations to buffer
-- @param buf number: Buffer number
-- @param cfg table: Configuration
function M.add_virtual_text(buf, cfg)
  if not cfg.advanced.virtual_text then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)

  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local timestamp_field = cfg.analysis.timestamp_field

  for i, line in ipairs(all_lines) do
    if line ~= "" then
      local parsed = json.parse(line)
      if parsed then
        local virt_text = {}

        -- Add relative timestamp
        local timestamp = json.get_field(parsed, timestamp_field)
        if timestamp then
          local relative = format_timestamp(timestamp)
          if relative ~= "" then
            table.insert(virt_text, { "  [" .. relative .. "]", "Comment" })
          end
        end

        -- Add duration if available
        local duration_ms = json.get_field(parsed, "duration_ms")
        if duration_ms then
          local duration = format_duration(duration_ms)
          if duration ~= "" then
            table.insert(virt_text, { "  ⏱ " .. duration, "Special" })
          end
        end

        -- Add annotations for specific fields
        local error = json.get_field(parsed, "error")
        if error and error ~= "" then
          table.insert(virt_text, { "  ⚠ " .. tostring(error), "ErrorMsg" })
        end

        if #virt_text > 0 then
          vim.api.nvim_buf_set_extmark(buf, M.namespace, i - 1, 0, {
            virt_text = virt_text,
            virt_text_pos = "eol",
          })
        end
      end
    end
  end
end

-- Clear virtual text from buffer
-- @param buf number: Buffer number
function M.clear_virtual_text(buf)
  vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
end

-- Toggle virtual text
-- @param ui_state table: UI state object
function M.toggle_virtual_text(ui_state)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  local cfg = config.get()
  cfg.advanced.virtual_text = not cfg.advanced.virtual_text

  if cfg.advanced.virtual_text then
    M.add_virtual_text(ui_state.source_buf, cfg)
    vim.notify("Virtual text enabled", vim.log.levels.INFO)
  else
    M.clear_virtual_text(ui_state.source_buf)
    vim.notify("Virtual text disabled", vim.log.levels.INFO)
  end
end

return M
