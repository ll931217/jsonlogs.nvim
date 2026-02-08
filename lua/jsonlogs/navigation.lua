-- Navigation features for jsonlogs.nvim
local json = require("jsonlogs.json")
local config = require("jsonlogs.config")
local stream = require("jsonlogs.stream")

local M = {}

-- Jump to next entry matching a condition
-- @param buf_or_file_path number|string: Source buffer or file path (for streaming mode)
-- @param start_line number: Starting line number
-- @param condition function: Function that takes parsed JSON and returns boolean
-- @param direction string: "forward" or "backward"
-- @param streaming_mode boolean: Whether to use streaming mode
-- @param total_lines number: Total lines in file (for streaming mode)
-- @return number|nil: Line number of match or nil if not found
local function jump_to_match(buf_or_file_path, start_line, condition, direction, streaming_mode, total_lines)
  local step = direction == "forward" and 1 or -1
  local current = start_line + step

  if streaming_mode then
    -- Streaming mode: iterate through file using stream module
    local max_iterations = total_lines or 1000000  -- Safety limit
    local iterations = 0

    while iterations < max_iterations do
      iterations = iterations + 1

      -- Wrap around
      if current < 1 then
        current = total_lines
      elseif current > total_lines then
        current = 1
      end

      if current == start_line then
        break  -- Full cycle, no match
      end

      local line = stream.get_line(buf_or_file_path, current)
      if line and line ~= "" then
        local parsed = json.parse(line)
        if parsed and condition(parsed) then
          return current
        end
      end

      current = current + step
    end
  else
    -- Non-streaming mode: use buffer
    local buf_total = vim.api.nvim_buf_line_count(buf_or_file_path)

    -- Wrap around
    while current ~= start_line do
      if current < 1 then
        current = buf_total
      elseif current > buf_total then
        current = 1
      end

      local lines = vim.api.nvim_buf_get_lines(buf_or_file_path, current - 1, current, false)
      if #lines > 0 then
        local parsed = json.parse(lines[1])
        if parsed and condition(parsed) then
          return current
        end
      end

      current = current + step
    end
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

  -- Convert buffer cursor position to actual line number if in streaming mode
  local actual_line = current_line
  if ui_state.streaming_mode then
    actual_line = ui_state.visible_range[1] + current_line - 1
  end

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

  local source = ui_state.streaming_mode and ui_state.file_path or ui_state.source_buf
  local match_line = jump_to_match(source, actual_line, is_error, "forward", ui_state.streaming_mode, ui_state.total_lines)

  if match_line then
    if ui_state.streaming_mode then
      -- In streaming mode, we need to load the chunk containing the match
      M._navigate_to_line_streaming(ui_state, match_line)
    else
      vim.api.nvim_win_set_cursor(ui_state.source_win, { match_line, 0 })
    end
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

  -- Convert buffer cursor position to actual line number if in streaming mode
  local actual_line = current_line
  if ui_state.streaming_mode then
    actual_line = ui_state.visible_range[1] + current_line - 1
  end

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

  local source = ui_state.streaming_mode and ui_state.file_path or ui_state.source_buf
  local match_line = jump_to_match(source, actual_line, is_error, "backward", ui_state.streaming_mode, ui_state.total_lines)

  if match_line then
    if ui_state.streaming_mode then
      -- In streaming mode, we need to load the chunk containing the match
      M._navigate_to_line_streaming(ui_state, match_line)
    else
      vim.api.nvim_win_set_cursor(ui_state.source_win, { match_line, 0 })
    end
  else
    vim.notify("No more errors found", vim.log.levels.INFO)
  end
end

-- Navigate to a specific line in streaming mode (loads chunk and positions cursor)
-- @param ui_state table: UI state object
-- @param target_line number: Target line number (1-indexed, actual line in file)
function M._navigate_to_line_streaming(ui_state, target_line)
  local cfg = config.get()
  local chunk_size = cfg.streaming.chunk_size

  -- Calculate which chunk to load (center target in chunk)
  local half_chunk = math.floor(chunk_size / 2)
  local chunk_start = math.max(1, target_line - half_chunk)
  local chunk_end = math.min(ui_state.total_lines, chunk_start + chunk_size - 1)

  -- Load the chunk
  local ui = require("jsonlogs.ui")
  ui.load_chunk(chunk_start, chunk_end)

  -- Position cursor on target line
  local cursor_line = target_line - chunk_start + 1
  vim.api.nvim_win_set_cursor(ui_state.source_win, { cursor_line, 0 })
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

  -- Convert buffer cursor position to actual line number if in streaming mode
  local actual_line = current_line
  if ui_state.streaming_mode then
    actual_line = ui_state.visible_range[1] + current_line - 1
  end

  local matches_field = function(parsed)
    return json.matches_filter(parsed, field, value)
  end

  local source = ui_state.streaming_mode and ui_state.file_path or ui_state.source_buf
  local match_line = jump_to_match(source, actual_line, matches_field, "forward", ui_state.streaming_mode, ui_state.total_lines)

  if match_line then
    if ui_state.streaming_mode then
      M._navigate_to_line_streaming(ui_state, match_line)
    else
      vim.api.nvim_win_set_cursor(ui_state.source_win, { match_line, 0 })
    end
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

  if ui_state.streaming_mode then
    -- Streaming mode: use iterator
    local total_lines = ui_state.total_lines

    for line_num, line in stream.iter_lines(ui_state.file_path, 1, total_lines) do
      if line and line ~= "" then
        local parsed = json.parse(line)
        if parsed then
          local entry_timestamp = json.get_field(parsed, timestamp_field)
          local entry_time = parse_timestamp(entry_timestamp, formats)

          if entry_time and entry_time >= target_time then
            M._navigate_to_line_streaming(ui_state, line_num)
            vim.notify(string.format("Jumped to line %d", line_num), vim.log.levels.INFO)
            return
          end
        end
      end
    end
  else
    -- Non-streaming mode: use buffer
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
