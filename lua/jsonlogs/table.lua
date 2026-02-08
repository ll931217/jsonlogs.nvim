-- Table preview mode for JSONL logs
local json = require("jsonlogs.json")
local config = require("jsonlogs.config")
local stream = require("jsonlogs.stream")

local M = {}

-- Flatten a JSON object to dot-notation keys
-- @param obj table|any: The object to flatten
-- @param prefix string: Current key prefix
-- @param result table: Accumulator for flattened keys
-- @return table: Flattened object with dot-notation keys
function M.flatten_json(obj, prefix, result)
  prefix = prefix or ""
  result = result or {}

  if type(obj) ~= "table" then
    result[prefix] = obj
    return result
  end

  -- Check if this is an array
  local is_array = vim.tbl_islist(obj)

  if is_array then
    -- Flatten array elements with [index] notation
    for i, value in ipairs(obj) do
      local key = prefix .. "[" .. (i - 1) .. "]"
      if type(value) == "table" then
        M.flatten_json(value, key, result)
      else
        result[key] = value
      end
    end
  else
    -- Flatten object properties with dot notation
    for key, value in pairs(obj) do
      local new_prefix = prefix == "" and key or (prefix .. "." .. key)
      if type(value) == "table" then
        M.flatten_json(value, new_prefix, result)
      else
        result[new_prefix] = value
      end
    end
  end

  return result
end

-- Scan buffer to discover all unique flattened keys
-- @param buf_or_file_path number|string: Buffer number or file path (for streaming mode)
-- @param streaming_mode boolean: Whether to use streaming mode (sampling)
-- @return table: Array of unique column names
function M.discover_all_columns(buf_or_file_path, streaming_mode)
  local cfg = config.get()
  local columns_set = {}
  local lines_to_scan

  if streaming_mode then
    -- In streaming mode, sample lines instead of loading all
    local file_path = buf_or_file_path
    local total_lines = stream.get_total_lines(file_path)
    local sample_size = cfg.streaming.table_sample_size or 1000

    -- Calculate step size for sampling
    local step = math.max(1, math.floor(total_lines / sample_size))

    -- Sample lines
    lines_to_scan = {}
    for i = 1, total_lines, step do
      local line = stream.get_line(file_path, i)
      if line and line ~= "" then
        table.insert(lines_to_scan, line)
      end
    end
  else
    -- Non-streaming mode: load all lines from buffer
    lines_to_scan = vim.api.nvim_buf_get_lines(buf_or_file_path, 0, -1, false)
  end

  for _, line in ipairs(lines_to_scan) do
    if line ~= "" then
      local parsed, err = json.parse(line)
      if parsed then
        local flattened = M.flatten_json(parsed)
        for key in pairs(flattened) do
          columns_set[key] = true
        end
      end
    end
  end

  -- Convert set to sorted array
  local columns = {}
  for key in pairs(columns_set) do
    table.insert(columns, key)
  end
  table.sort(columns)

  return columns
end

-- Calculate the display width of a string (handles multi-byte characters)
-- @param str string: String to measure
-- @return number: Display width
local function display_width(str)
  return vim.fn.strdisplaywidth(str)
end

-- Truncate string to fit max width with ellipsis
-- @param str string: String to truncate
-- @param max_width number: Maximum width
-- @return string: Truncated string
local function truncate_string(str, max_width)
  if display_width(str) <= max_width then
    return str
  end

  -- Truncate and add ellipsis
  local truncated = str:sub(1, max_width - 3)
  while display_width(truncated) > max_width - 3 do
    truncated = truncated:sub(1, -2)
  end
  return truncated .. "..."
end

-- Format value for table display
-- @param value any: Value to format
-- @param max_width number: Maximum column width
-- @param placeholder string: Placeholder for nil values
-- @return string: Formatted value
local function format_value(value, max_width, placeholder)
  if value == nil then
    return placeholder
  end

  local str
  if type(value) == "table" then
    str = vim.fn.json_encode(value)
  elseif type(value) == "boolean" then
    str = value and "true" or "false"
  else
    str = tostring(value)
  end

  return truncate_string(str, max_width)
end

-- Calculate column widths based on content
-- @param entries table: Array of flattened entry objects
-- @param columns table: Array of column names to include
-- @param cfg table: Configuration object
-- @return table: Map of column name to width
local function calculate_column_widths(entries, columns, cfg)
  local widths = {}
  local max_width = cfg.display.table_max_col_width or 30

  -- Initialize with header widths
  for _, col in ipairs(columns) do
    widths[col] = display_width(col)
  end

  -- Check all entry values
  for _, entry in ipairs(entries) do
    for _, col in ipairs(columns) do
      local value = entry[col]
      local formatted = format_value(value, max_width, cfg.display.table_null_placeholder or "-")
      local width = display_width(formatted)
      if width > widths[col] then
        widths[col] = math.min(width, max_width)
      end
    end
  end

  return widths
end

-- Format multiple entries as markdown table lines
-- @param lines table: Array of JSONL strings
-- @param columns table: Array of column names to include (nil = all)
-- @param cfg table: Configuration object
-- @return table: { lines = table_array, metadata = cell_metadata }
--   lines: Array of markdown table lines
--   metadata: { row_num -> { col_name -> { value, truncated, type, length } } }
function M.format_table(lines, columns, cfg)
  local entries = {}
  local flattened_entries = {}

  -- Parse and flatten all entries
  for _, line in ipairs(lines) do
    if line ~= "" then
      local parsed, err = json.parse(line)
      if parsed then
        table.insert(entries, parsed)
        table.insert(flattened_entries, M.flatten_json(parsed))
      end
    end
  end

  if #flattened_entries == 0 then
    return { lines = { "No valid JSON entries found" }, metadata = {} }
  end

  -- Use all discovered columns if none specified
  if not columns or #columns == 0 then
    local columns_set = {}
    for _, entry in ipairs(flattened_entries) do
      for key in pairs(entry) do
        columns_set[key] = true
      end
    end
    columns = {}
    for key in pairs(columns_set) do
      table.insert(columns, key)
    end
    table.sort(columns)
  end

  -- Calculate column widths
  local widths = calculate_column_widths(flattened_entries, columns, cfg)

  -- Build table lines and metadata
  local result = {}
  local metadata = {}
  local placeholder = cfg.display.table_null_placeholder or "-"
  local max_width = cfg.display.table_max_col_width or 30

  -- Helper to get value type
  local function get_value_type(val)
    if val == nil then
      return "null"
    elseif type(val) == "boolean" then
      return "boolean"
    elseif type(val) == "number" then
      return "number"
    elseif type(val) == "string" then
      return "string"
    elseif type(val) == "table" then
      return vim.tbl_islist(val) and "array" or "object"
    end
    return "unknown"
  end

  -- Header row
  local header_parts = {}
  for _, col in ipairs(columns) do
    local padded = col .. string.rep(" ", widths[col] - display_width(col))
    table.insert(header_parts, padded)
  end
  table.insert(result, "| " .. table.concat(header_parts, " | ") .. " |")

  -- Separator row
  local separator_parts = {}
  for _, col in ipairs(columns) do
    table.insert(separator_parts, string.rep("-", widths[col]))
  end
  table.insert(result, "|" .. table.concat(separator_parts, "|") .. "|")

  -- Data rows with metadata tracking
  -- Row 1 in result = header, Row 2 = separator, so data starts at row 3
  for row_idx, entry in ipairs(flattened_entries) do
    local result_row_idx = row_idx + 2  -- Account for header and separator
    metadata[result_row_idx] = {}

    local row_parts = {}
    for _, col in ipairs(columns) do
      local value = entry[col]
      local value_type = get_value_type(value)

      -- Format the value for display
      local formatted = format_value(value, max_width, placeholder)

      -- Track whether value was truncated
      local original_value
      if value == nil then
        original_value = nil
      elseif type(value) == "table" then
        original_value = vim.fn.json_encode(value)
      elseif type(value) == "boolean" then
        original_value = value and "true" or "false"
      else
        original_value = tostring(value)
      end

      local is_truncated = original_value ~= nil and formatted ~= original_value

      -- Store metadata for this cell
      metadata[result_row_idx][col] = {
        value = original_value,
        truncated = is_truncated,
        type = value_type,
        length = original_value and display_width(original_value) or 0,
      }

      local padded = formatted .. string.rep(" ", widths[col] - display_width(formatted))
      table.insert(row_parts, padded)
    end
    table.insert(result, "| " .. table.concat(row_parts, " | ") .. " |")
  end

  return {
    lines = result,
    metadata = metadata,
  }
end

-- Show column filter floating modal
-- @param ui_state table: UI state object
-- @param on_confirm function: Callback when columns are confirmed
function M.show_column_filter(ui_state, on_confirm)
  if not ui_state.source_buf and not ui_state.file_path then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  -- Discover all columns
  local source = ui_state.streaming_mode and ui_state.file_path or ui_state.source_buf
  local all_columns = M.discover_all_columns(source, ui_state.streaming_mode)
  if #all_columns == 0 then
    vim.notify("No columns found", vim.log.levels.WARN)
    return
  end

  -- Initialize selection state (all selected by default)
  local selected = {}
  local current_selection = ui_state.table_columns or all_columns
  for _, col in ipairs(all_columns) do
    selected[col] = vim.tbl_contains(current_selection, col)
  end

  -- Create buffer for column list
  local buf = vim.api.nvim_create_buf(false, true)
  local cursor_pos = 1

  local function render()
    local lines = {}
    table.insert(lines, "Select columns (Space=toggle, Enter=confirm)")
    table.insert(lines, "")

    for i, col in ipairs(all_columns) do
      local checkbox = selected[col] and "[x]" or "[ ]"
      table.insert(lines, string.format("%s %s", checkbox, col))
    end

    table.insert(lines, "")
    local selected_count = 0
    for _, is_selected in pairs(selected) do
      if is_selected then
        selected_count = selected_count + 1
      end
    end
    table.insert(lines, string.format("Showing %d of %d columns", selected_count, #all_columns))

    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end

  render()

  -- Create floating window
  local width = 50
  local height = math.min(#all_columns + 5, 30)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = " Column Filter ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set cursor to first column
  vim.api.nvim_win_set_cursor(win, { 3, 0 })

  -- Helper to get current column index
  local function get_current_column()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local line_num = cursor[1]
    -- Lines 1-2 are header, line 3+ are columns, last line is summary
    if line_num < 3 or line_num > #all_columns + 2 then
      return nil
    end
    return line_num - 2
  end

  -- Toggle current column
  local function toggle_current()
    local idx = get_current_column()
    if idx then
      local col = all_columns[idx]
      selected[col] = not selected[col]
      render()
      -- Restore cursor position
      vim.api.nvim_win_set_cursor(win, { idx + 2, 0 })
    end
  end

  -- Select all columns
  local function select_all()
    for _, col in ipairs(all_columns) do
      selected[col] = true
    end
    render()
  end

  -- Deselect all columns
  local function select_none()
    for _, col in ipairs(all_columns) do
      selected[col] = false
    end
    render()
  end

  -- Confirm selection
  local function confirm()
    local chosen = {}
    for _, col in ipairs(all_columns) do
      if selected[col] then
        table.insert(chosen, col)
      end
    end

    vim.api.nvim_win_close(win, true)
    on_confirm(chosen)
  end

  -- Cancel
  local function cancel()
    vim.api.nvim_win_close(win, true)
  end

  -- Set up keymaps
  local keymap_opts = { buffer = buf, noremap = true, silent = true }

  vim.keymap.set("n", "<Space>", toggle_current, keymap_opts)
  vim.keymap.set("n", "<CR>", confirm, keymap_opts)
  vim.keymap.set("n", "a", select_all, keymap_opts)
  vim.keymap.set("n", "n", select_none, keymap_opts)
  vim.keymap.set("n", "q", cancel, keymap_opts)
  vim.keymap.set("n", "<ESC>", cancel, keymap_opts)

  -- Allow j/k navigation
  vim.keymap.set("n", "j", function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local max_line = #all_columns + 2
    if cursor[1] < max_line then
      vim.api.nvim_win_set_cursor(win, { cursor[1] + 1, 0 })
    end
  end, keymap_opts)

  vim.keymap.set("n", "k", function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    if cursor[1] > 3 then
      vim.api.nvim_win_set_cursor(win, { cursor[1] - 1, 0 })
    end
  end, keymap_opts)
end

-- Show cell inspection popup
-- @param ui_state table: UI state object
function M.show_cell_inspection(ui_state)
  if not ui_state.preview_buf or not ui_state.table_cell_metadata then
    vim.notify("Table mode not active or no metadata available", vim.log.levels.WARN)
    return
  end

  -- Get cursor position in preview buffer
  local cursor = vim.api.nvim_win_get_cursor(ui_state.preview_win)
  local row_num = cursor[1]
  local col_num = cursor[2] + 1  -- Convert from 0-based

  -- Get metadata for this row
  local row_data = ui_state.table_cell_metadata[row_num]
  if not row_data then
    vim.notify("No data for this row", vim.log.levels.WARN)
    return
  end

  -- Find which column the cursor is in
  local line = vim.api.nvim_buf_get_lines(ui_state.preview_buf, row_num - 1, row_num, true)[1]
  local col_name, col_idx = M._find_column_at_cursor(line, col_num, ui_state.table_columns)

  if not col_name or not row_data[col_name] then
    vim.notify("No cell data at cursor position", vim.log.levels.WARN)
    return
  end

  local cell_data = row_data[col_name]

  -- Build popup content
  local lines = {
    "Cell Inspection",
    string.rep("─", 40),
    "",
    string.format("Column: %s", col_name),
    string.format("Type: %s", cell_data.type),
    string.format("Length: %d characters", cell_data.length),
    "",
    "Value (wrapped):",
    "",
  }

  -- Format the value for display
  local value_str = cell_data.value or "-"
  if cell_data.type == "object" or cell_data.type == "array" then
    -- Pretty print JSON
    local parsed = vim.fn.json_decode(cell_data.value)
    if parsed then
      value_str = vim.fn.json_encode(parsed):gsub(",", ",\n"):gsub("{", "{\n"):gsub("}", "\n}"):gsub("%[", "[\n"):gsub("%]", "\n]")
      -- Indent the JSON
      local indented = {}
      local indent = 0
      for line_part in value_str:gmatch("[^\n]+") do
        if line_part:match("^[}%]]") then
          indent = math.max(0, indent - 2)
        end
        table.insert(indented, string.rep(" ", indent) .. line_part)
        if line_part:match("^[{%[]$") or line_part:match("[{%[]$") then
          indent = indent + 2
        end
      end
      value_str = table.concat(indented, "\n")
    end
  end

  -- Helper function to wrap text at word boundaries
  local function wrap_text(text, max_width)
    if #text <= max_width then
      return { text }
    end

    local wrapped = {}
    local current_line = ""

    for word in text:gmatch("%S+") do
      if #current_line == 0 then
        current_line = word
      elseif #current_line + 1 + #word <= max_width then
        current_line = current_line .. " " .. word
      else
        table.insert(wrapped, current_line)
        current_line = word
      end
    end

    if #current_line > 0 then
      table.insert(wrapped, current_line)
    end

    return wrapped
  end

  -- Split value by existing newlines and wrap each line
  local max_width = 100
  for value_line in value_str:gmatch("[^\n]+") do
    local wrapped_lines = wrap_text(value_line, max_width)
    for _, wrapped_line in ipairs(wrapped_lines) do
      table.insert(lines, wrapped_line)
    end
  end

  table.insert(lines, "")
  table.insert(lines, string.rep("─", 40))
  table.insert(lines, "Press 'q' to close, 'z' to zoom this column")

  -- Create popup buffer and window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(#lines + 4, vim.o.lines - 10)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = " Cell Inspection ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set up keymaps
  local keymap_opts = { buffer = buf, noremap = true, silent = true }

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, keymap_opts)

  vim.keymap.set("n", "<ESC>", function()
    vim.api.nvim_win_close(win, true)
  end, keymap_opts)

  vim.keymap.set("n", "<CR>", function()
    vim.api.nvim_win_close(win, true)
  end, keymap_opts)

  vim.keymap.set("n", "z", function()
    vim.api.nvim_win_close(win, true)
    M.show_column_zoom(ui_state, col_name)
  end, keymap_opts)
end

-- Find which column the cursor is in
-- @param line string: The table row line
-- @param col_num number: The cursor column position (1-based)
-- @param columns table: Array of column names
-- @return string|nil, number|nil: Column name and index
function M._find_column_at_cursor(line, col_num, columns)
  if not columns then
    return nil, nil
  end

  -- Find all pipe positions
  local pipe_positions = {}
  for pos = 1, #line do
    local char = line:sub(pos, pos)
    if char == "|" then
      table.insert(pipe_positions, pos)
    end
  end

  -- Find which column range contains the cursor
  for i = 1, #pipe_positions - 1 do
    local start_pos = pipe_positions[i]
    local end_pos = pipe_positions[i + 1]
    if col_num >= start_pos and col_num < end_pos then
      local col_name = columns[i]
      return col_name, i
    end
  end

  return nil, nil
end

-- Show column zoom view (all values for a single column)
-- @param ui_state table: UI state object
-- @param col_name string: Column name to zoom
function M.show_column_zoom(ui_state, col_name)
  if not ui_state.source_buf and not ui_state.file_path then
    vim.notify("No data available", vim.log.levels.ERROR)
    return
  end

  -- Get current page lines
  local lines
  if ui_state.streaming_mode then
    lines = vim.api.nvim_buf_get_lines(ui_state.source_buf, 0, -1, false)
  else
    lines = ui_state._get_current_page_lines and ui_state._get_current_page_lines()
    if not lines then
      lines = vim.api.nvim_buf_get_lines(ui_state.source_buf, 0, -1, false)
    end
  end

  if not lines then
    vim.notify("Unable to retrieve data", vim.log.levels.ERROR)
    return
  end

  -- Parse and extract column values
  local entries = {}
  for i, line in ipairs(lines) do
    if line ~= "" then
      local parsed = json.parse(line)
      if parsed then
        local flattened = M.flatten_json(parsed)
        local value = flattened[col_name]

        -- Format value for display
        local formatted
        if value == nil then
          formatted = "-"
        elseif type(value) == "table" then
          formatted = vim.fn.json_encode(value)
        elseif type(value) == "boolean" then
          formatted = value and "true" or "false"
        else
          formatted = tostring(value)
        end

        table.insert(entries, {
          line_num = i,
          value = formatted,
          original = value,
        })
      end
    end
  end

  if #entries == 0 then
    vim.notify("No entries found", vim.log.levels.WARN)
    return
  end

  -- Create zoom buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Helper to render entries
  local function render(start_idx)
    start_idx = start_idx or 1
    local page_size = 50
    local end_idx = math.min(start_idx + page_size - 1, #entries)

    local display_lines = {
      string.format("Column Zoom: %s", col_name),
      string.rep("─", 60),
      string.format("Showing entries %d-%d of %d", start_idx, end_idx, #entries),
      "",
    }

    for i = start_idx, end_idx do
      local entry = entries[i]
      local value_preview = entry.value
      if #value_preview > 100 then
        value_preview = value_preview:sub(1, 97) .. "..."
      end
      table.insert(display_lines, string.format("[%d] %s", entry.line_num, value_preview))
    end

    if end_idx < #entries then
      table.insert(display_lines, "")
      table.insert(display_lines, string.format("-- More -- (Press ] for next, [ for prev)"))
    end

    table.insert(display_lines, "")
    table.insert(display_lines, "Press 'q' to close")

    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    return end_idx
  end

  local current_start = 1
  render(current_start)

  -- Create popup window
  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(30, vim.o.lines - 10)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = string.format(" Column Zoom: %s ", col_name),
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set up keymaps
  local keymap_opts = { buffer = buf, noremap = true, silent = true }

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, keymap_opts)

  vim.keymap.set("n", "<ESC>", function()
    vim.api.nvim_win_close(win, true)
  end, keymap_opts)

  vim.keymap.set("n", "]", function()
    if current_start + 50 <= #entries then
      current_start = current_start + 50
      render(current_start)
    end
  end, keymap_opts)

  vim.keymap.set("n", "[", function()
    if current_start > 50 then
      current_start = current_start - 50
    else
      current_start = 1
    end
    render(current_start)
  end, keymap_opts)
end

return M
