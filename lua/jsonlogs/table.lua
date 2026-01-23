-- Table preview mode for JSONL logs
local json = require("jsonlogs.json")
local config = require("jsonlogs.config")

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
-- @param buf number: Buffer number
-- @return table: Array of unique column names
function M.discover_all_columns(buf)
  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local columns_set = {}

  for _, line in ipairs(all_lines) do
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
-- @return table: Array of markdown table lines
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
    return { "No valid JSON entries found" }
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

  -- Build table lines
  local result = {}
  local placeholder = cfg.display.table_null_placeholder or "-"
  local max_width = cfg.display.table_max_col_width or 30

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

  -- Data rows
  for _, entry in ipairs(flattened_entries) do
    local row_parts = {}
    for _, col in ipairs(columns) do
      local value = entry[col]
      local formatted = format_value(value, max_width, placeholder)
      local padded = formatted .. string.rep(" ", widths[col] - display_width(formatted))
      table.insert(row_parts, padded)
    end
    table.insert(result, "| " .. table.concat(row_parts, " | ") .. " |")
  end

  return result
end

-- Show column filter floating modal
-- @param ui_state table: UI state object
-- @param on_confirm function: Callback when columns are confirmed
function M.show_column_filter(ui_state, on_confirm)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  -- Discover all columns
  local all_columns = M.discover_all_columns(ui_state.source_buf)
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

return M
