-- Navigation features for jsonlogs.nvim
local json = require("jsonlogs.json")
local config = require("jsonlogs.config")

local M = {}

-- Jump to next entry matching a condition
-- @param buf number: Source buffer
-- @param start_line number: Starting line number
-- @param condition function: Function that takes parsed JSON and returns boolean
-- @param direction string: "forward" or "backward"
-- @return number|nil: Line number of match or nil if not found
local function jump_to_match(buf, start_line, condition, direction)
  local total_lines = vim.api.nvim_buf_line_count(buf)
  local step = direction == "forward" and 1 or -1
  local current = start_line + step

  -- Wrap around
  while current ~= start_line do
    if current < 1 then
      current = total_lines
    elseif current > total_lines then
      current = 1
    end

    local lines = vim.api.nvim_buf_get_lines(buf, current - 1, current, false)
    if #lines > 0 then
      local parsed = json.parse(lines[1])
      if parsed and condition(parsed) then
        return current
      end
    end

    current = current + step
  end

  return nil
end

-- Jump to next error-level log
-- @param ui_state table: UI state object
function M.jump_to_next_error(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  local cfg = config.get()
  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  local is_error = function(parsed)
    local level = json.get_field(parsed, cfg.navigation.error_field)
    if not level then
      return false
    end

    local level_lower = type(level) == "string" and string.lower(level) or ""
    for _, error_value in ipairs(cfg.navigation.error_values) do
      if level_lower == string.lower(error_value) then
        return true
      end
    end
    return false
  end

  local match_line = jump_to_match(ui_state.source_buf, current_line, is_error, "forward")
  if match_line then
    vim.api.nvim_win_set_cursor(ui_state.source_win, { match_line, 0 })
  else
    vim.notify("No more errors found", vim.log.levels.INFO)
  end
end

-- Jump to previous error-level log
-- @param ui_state table: UI state object
function M.jump_to_prev_error(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  local cfg = config.get()
  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  local is_error = function(parsed)
    local level = json.get_field(parsed, cfg.navigation.error_field)
    if not level then
      return false
    end

    local level_lower = type(level) == "string" and string.lower(level) or ""
    for _, error_value in ipairs(cfg.navigation.error_values) do
      if level_lower == string.lower(error_value) then
        return true
      end
    end
    return false
  end

  local match_line = jump_to_match(ui_state.source_buf, current_line, is_error, "backward")
  if match_line then
    vim.api.nvim_win_set_cursor(ui_state.source_win, { match_line, 0 })
  else
    vim.notify("No more errors found", vim.log.levels.INFO)
  end
end

-- Search for entries matching a field value
-- @param ui_state table: UI state object
-- @param field string: Field name (dot-separated path)
-- @param value any: Value to match
function M.search_by_field(ui_state, field, value)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  local matches_field = function(parsed)
    return json.matches_filter(parsed, field, value)
  end

  local match_line = jump_to_match(ui_state.source_buf, current_line, matches_field, "forward")
  if match_line then
    vim.api.nvim_win_set_cursor(ui_state.source_win, { match_line, 0 })
    vim.notify(string.format("Found match at line %d", match_line), vim.log.levels.INFO)
  else
    vim.notify(string.format("No match found for %s=%s", field, value), vim.log.levels.WARN)
  end
end

-- Prompt user for search field and value
-- @param ui_state table: UI state object
function M.prompt_search(ui_state)
  vim.ui.input({ prompt = "Search field (e.g., user_id): " }, function(field)
    if not field or field == "" then
      return
    end

    vim.ui.input({ prompt = "Search value: " }, function(value)
      if not value or value == "" then
        return
      end

      M.search_by_field(ui_state, field, value)
    end)
  end)
end

-- Parse timestamp from string
-- @param timestamp_str string: Timestamp string
-- @param formats table: Array of format strings
-- @return number|nil: Unix timestamp or nil if parse fails
local function parse_timestamp(timestamp_str, formats)
  if not timestamp_str then
    return nil
  end

  -- Try ISO8601 first (Neovim has built-in support)
  if type(timestamp_str) == "string" and timestamp_str:match("%d%d%d%d%-%d%d%-%d%dT") then
    -- Parse ISO8601 timestamp
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

  -- Try custom formats
  for _, format in ipairs(formats) do
    if format ~= "iso8601" then
      local ok, result = pcall(function()
        return os.time(os.date(format, timestamp_str))
      end)
      if ok and result then
        return result
      end
    end
  end

  return nil
end

-- Jump to entry at or after a timestamp
-- @param ui_state table: UI state object
-- @param target_timestamp string: Target timestamp
function M.jump_to_timestamp(ui_state, target_timestamp)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  local cfg = config.get()
  local timestamp_field = cfg.analysis.timestamp_field
  local formats = cfg.analysis.timestamp_formats

  local target_time = parse_timestamp(target_timestamp, formats)
  if not target_time then
    vim.notify("Invalid timestamp format", vim.log.levels.ERROR)
    return
  end

  -- Linear search through file (could be optimized with binary search)
  local total_lines = vim.api.nvim_buf_line_count(ui_state.source_buf)

  for i = 1, total_lines do
    local lines = vim.api.nvim_buf_get_lines(ui_state.source_buf, i - 1, i, false)
    if #lines > 0 then
      local parsed = json.parse(lines[1])
      if parsed then
        local entry_timestamp = json.get_field(parsed, timestamp_field)
        local entry_time = parse_timestamp(entry_timestamp, formats)

        if entry_time and entry_time >= target_time then
          vim.api.nvim_win_set_cursor(ui_state.source_win, { i, 0 })
          vim.notify(string.format("Jumped to line %d", i), vim.log.levels.INFO)
          return
        end
      end
    end
  end

  vim.notify("No entry found at or after that timestamp", vim.log.levels.WARN)
end

-- Prompt user for timestamp navigation
-- @param ui_state table: UI state object
function M.prompt_timestamp_goto(ui_state)
  vim.ui.input({ prompt = "Jump to timestamp (YYYY-MM-DDTHH:MM:SS): " }, function(timestamp)
    if not timestamp or timestamp == "" then
      return
    end

    M.jump_to_timestamp(ui_state, timestamp)
  end)
end

return M
