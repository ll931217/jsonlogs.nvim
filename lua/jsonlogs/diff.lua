-- Diff view for comparing log entries
local json = require("jsonlogs.json")
local highlights = require("jsonlogs.highlights")

local M = {}

-- Mark current line for diff
-- @param ui_state table: UI state object
function M.mark_for_diff(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  if ui_state.marked_line == current_line then
    -- Unmark
    ui_state.marked_line = nil
    highlights.highlight_marked_line(ui_state.source_buf, nil)
    vim.notify("Unmarked line for diff", vim.log.levels.INFO)
  else
    -- Mark
    ui_state.marked_line = current_line
    highlights.highlight_marked_line(ui_state.source_buf, current_line)
    vim.notify(string.format("Marked line %d for diff", current_line), vim.log.levels.INFO)
  end
end

-- Show diff between marked line and current line
-- @param ui_state table: UI state object
function M.show_diff(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  if not ui_state.marked_line then
    vim.notify("No line marked for diff. Press 'd' to mark a line first.", vim.log.levels.WARN)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  if current_line == ui_state.marked_line then
    vim.notify("Cannot diff a line with itself", vim.log.levels.WARN)
    return
  end

  -- Get both lines
  local line1 = vim.api.nvim_buf_get_lines(
    ui_state.source_buf,
    ui_state.marked_line - 1,
    ui_state.marked_line,
    false
  )[1]
  local line2 = vim.api.nvim_buf_get_lines(ui_state.source_buf, current_line - 1, current_line, false)[1]

  -- Parse JSON
  local obj1, err1 = json.parse(line1)
  local obj2, err2 = json.parse(line2)

  if not obj1 or not obj2 then
    vim.notify("Error parsing JSON for diff: " .. (err1 or err2), vim.log.levels.ERROR)
    return
  end

  -- Create diff buffers
  local cfg = require("jsonlogs.config").get()

  -- Format both objects
  local lines1 = json.pretty_print(obj1, cfg.json)
  local lines2 = json.pretty_print(obj2, cfg.json)

  -- Create scratch buffers for diff
  local buf1 = vim.api.nvim_create_buf(false, true)
  local buf2 = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf1, 0, -1, false, lines1)
  vim.api.nvim_buf_set_lines(buf2, 0, -1, false, lines2)

  vim.api.nvim_buf_set_option(buf1, "filetype", "json")
  vim.api.nvim_buf_set_option(buf2, "filetype", "json")
  vim.api.nvim_buf_set_option(buf1, "modifiable", false)
  vim.api.nvim_buf_set_option(buf2, "modifiable", false)

  -- Open diff in new tab
  vim.cmd("tabnew")
  local win1 = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win1, buf1)

  vim.cmd("vsplit")
  local win2 = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win2, buf2)

  -- Enable diff mode
  vim.cmd("windo diffthis")

  -- Set titles
  vim.api.nvim_buf_set_name(buf1, string.format("Line %d (marked)", ui_state.marked_line))
  vim.api.nvim_buf_set_name(buf2, string.format("Line %d (current)", current_line))

  vim.notify("Diff view opened in new tab. Close tab when done.", vim.log.levels.INFO)
end

-- Compare fields between two objects and show differences
-- @param obj1 table: First JSON object
-- @param obj2 table: Second JSON object
-- @return table: Array of difference descriptions
local function compare_objects(obj1, obj2, prefix)
  prefix = prefix or ""
  local diffs = {}

  -- Get all keys from both objects
  local all_keys = {}
  for k in pairs(obj1) do
    all_keys[k] = true
  end
  for k in pairs(obj2) do
    all_keys[k] = true
  end

  for key in pairs(all_keys) do
    local full_key = prefix == "" and key or (prefix .. "." .. key)
    local val1 = obj1[key]
    local val2 = obj2[key]

    if val1 == nil and val2 ~= nil then
      table.insert(diffs, string.format("+ %s: %s", full_key, vim.inspect(val2)))
    elseif val1 ~= nil and val2 == nil then
      table.insert(diffs, string.format("- %s: %s", full_key, vim.inspect(val1)))
    elseif type(val1) == "table" and type(val2) == "table" then
      -- Recursive comparison
      local nested_diffs = compare_objects(val1, val2, full_key)
      for _, diff in ipairs(nested_diffs) do
        table.insert(diffs, diff)
      end
    elseif val1 ~= val2 then
      table.insert(diffs, string.format("~ %s: %s -> %s", full_key, vim.inspect(val1), vim.inspect(val2)))
    end
  end

  return diffs
end

-- Show field-level diff inline
-- @param ui_state table: UI state object
function M.show_inline_diff(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  if not ui_state.marked_line then
    vim.notify("No line marked for diff. Press 'd' to mark a line first.", vim.log.levels.WARN)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  -- Get both lines
  local line1 = vim.api.nvim_buf_get_lines(
    ui_state.source_buf,
    ui_state.marked_line - 1,
    ui_state.marked_line,
    false
  )[1]
  local line2 = vim.api.nvim_buf_get_lines(ui_state.source_buf, current_line - 1, current_line, false)[1]

  -- Parse JSON
  local obj1, err1 = json.parse(line1)
  local obj2, err2 = json.parse(line2)

  if not obj1 or not obj2 then
    vim.notify("Error parsing JSON: " .. (err1 or err2), vim.log.levels.ERROR)
    return
  end

  -- Compare objects
  local diffs = compare_objects(obj1, obj2)

  if #diffs == 0 then
    vim.notify("No differences found", vim.log.levels.INFO)
    return
  end

  -- Show diffs in a float window
  local width = 80
  local height = math.min(#diffs + 2, 20)

  local buf = vim.api.nvim_create_buf(false, true)
  local title = string.format("Differences (Line %d vs %d)", ui_state.marked_line, current_line)

  local content = { title, string.rep("=", #title), "" }
  for _, diff in ipairs(diffs) do
    table.insert(content, diff)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Close on any key
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set("n", "<ESC>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })
end

return M
