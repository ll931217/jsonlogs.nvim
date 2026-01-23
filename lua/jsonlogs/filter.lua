-- Filtering functionality for JSONL logs
local json = require("jsonlogs.json")
local config = require("jsonlogs.config")

local M = {}

-- Parse timestamp string to Unix time
-- @param timestamp_str string: Timestamp string
-- @return number|nil: Unix timestamp or nil
local function parse_timestamp(timestamp_str)
  if not timestamp_str then
    return nil
  end

  -- Try ISO8601 format
  if type(timestamp_str) == "string" and timestamp_str:match("%d%d%d%d%-%d%d%-%d%dT") then
    local year, month, day, hour, min, sec = timestamp_str:match(
      "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)"
    )
    if year then
      return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
      })
    end
  end

  return nil
end

-- Filter logs by time range
-- @param buf number: Source buffer
-- @param from_time string: Start timestamp (ISO8601)
-- @param to_time string: End timestamp (ISO8601)
-- @return table: Array of {line_num, line_content} for matching entries
function M.filter_by_time_range(buf, from_time, to_time)
  local cfg = config.get()
  local timestamp_field = cfg.analysis.timestamp_field
  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local from_unix = parse_timestamp(from_time)
  local to_unix = parse_timestamp(to_time)

  if not from_unix or not to_unix then
    vim.notify("Invalid timestamp format. Use YYYY-MM-DDTHH:MM:SS", vim.log.levels.ERROR)
    return {}
  end

  local matches = {}

  for i, line in ipairs(all_lines) do
    if line ~= "" then
      local parsed = json.parse(line)
      if parsed then
        local entry_timestamp = json.get_field(parsed, timestamp_field)
        local entry_unix = parse_timestamp(entry_timestamp)

        if entry_unix and entry_unix >= from_unix and entry_unix <= to_unix then
          table.insert(matches, { line_num = i, content = line })
        end
      end
    end
  end

  return matches
end

-- Filter logs by field value
-- @param buf number: Source buffer
-- @param field string: Field name
-- @param value any: Field value to match
-- @return table: Array of {line_num, line_content} for matching entries
function M.filter_by_field(buf, field, value)
  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local matches = {}

  for i, line in ipairs(all_lines) do
    if line ~= "" then
      local parsed = json.parse(line)
      if parsed and json.matches_filter(parsed, field, value) then
        table.insert(matches, { line_num = i, content = line })
      end
    end
  end

  return matches
end

-- Filter logs by level
-- @param buf number: Source buffer
-- @param level string: Log level (e.g., "error", "warn")
-- @return table: Array of {line_num, line_content} for matching entries
function M.filter_by_level(buf, level)
  local cfg = config.get()
  local level_field = cfg.navigation.error_field
  return M.filter_by_field(buf, level_field, level)
end

-- Create filtered view in new buffer
-- @param matches table: Array of {line_num, line_content}
-- @param title string: Buffer title
function M.create_filtered_view(matches, title)
  if #matches == 0 then
    vim.notify("No matching entries found", vim.log.levels.WARN)
    return
  end

  -- Create new buffer
  local buf = vim.api.nvim_create_buf(true, false)
  local lines = {}

  for _, match in ipairs(matches) do
    table.insert(lines, match.content)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, title)
  vim.api.nvim_buf_set_option(buf, "filetype", "jsonl")

  -- Open in new tab
  vim.cmd("tabnew")
  vim.api.nvim_win_set_buf(0, buf)

  vim.notify(string.format("Filtered view: %d entries", #matches), vim.log.levels.INFO)
end

-- Prompt for time range filter
-- @param ui_state table: UI state object
function M.prompt_time_range_filter(ui_state)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({ prompt = "From timestamp (YYYY-MM-DDTHH:MM:SS): " }, function(from_time)
    if not from_time or from_time == "" then
      return
    end

    vim.ui.input({ prompt = "To timestamp (YYYY-MM-DDTHH:MM:SS): " }, function(to_time)
      if not to_time or to_time == "" then
        return
      end

      local matches = M.filter_by_time_range(ui_state.source_buf, from_time, to_time)
      M.create_filtered_view(matches, string.format("Filtered: %s to %s", from_time, to_time))
    end)
  end)
end

-- Prompt for level filter
-- @param ui_state table: UI state object
function M.prompt_level_filter(ui_state)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  local levels = { "error", "warn", "info", "debug" }

  vim.ui.select(levels, {
    prompt = "Filter by level:",
  }, function(choice)
    if not choice then
      return
    end

    local matches = M.filter_by_level(ui_state.source_buf, choice)
    M.create_filtered_view(matches, string.format("Filtered: level=%s", choice))
  end)
end

return M
