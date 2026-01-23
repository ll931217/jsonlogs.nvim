-- Bookmark management for jsonlogs.nvim
local highlights = require("jsonlogs.highlights")

local M = {}

-- Toggle bookmark on current line
-- @param ui_state table: UI state object
function M.toggle_bookmark(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  -- Check if line is already bookmarked
  local idx = nil
  for i, line in ipairs(ui_state.bookmarks) do
    if line == current_line then
      idx = i
      break
    end
  end

  if idx then
    -- Remove bookmark
    table.remove(ui_state.bookmarks, idx)
    vim.notify(string.format("Removed bookmark from line %d", current_line), vim.log.levels.INFO)
  else
    -- Add bookmark
    table.insert(ui_state.bookmarks, current_line)
    table.sort(ui_state.bookmarks)
    vim.notify(string.format("Bookmarked line %d", current_line), vim.log.levels.INFO)
  end

  -- Update highlights
  highlights.highlight_bookmarks(ui_state.source_buf, ui_state.bookmarks)
end

-- Jump to next bookmark
-- @param ui_state table: UI state object
function M.next_bookmark(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  if #ui_state.bookmarks == 0 then
    vim.notify("No bookmarks set", vim.log.levels.WARN)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  -- Find next bookmark
  for _, line in ipairs(ui_state.bookmarks) do
    if line > current_line then
      vim.api.nvim_win_set_cursor(ui_state.source_win, { line, 0 })
      return
    end
  end

  -- Wrap to first bookmark
  vim.api.nvim_win_set_cursor(ui_state.source_win, { ui_state.bookmarks[1], 0 })
end

-- Jump to previous bookmark
-- @param ui_state table: UI state object
function M.prev_bookmark(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  if #ui_state.bookmarks == 0 then
    vim.notify("No bookmarks set", vim.log.levels.WARN)
    return
  end

  local current_line = vim.api.nvim_win_get_cursor(ui_state.source_win)[1]

  -- Find previous bookmark (search backwards)
  for i = #ui_state.bookmarks, 1, -1 do
    local line = ui_state.bookmarks[i]
    if line < current_line then
      vim.api.nvim_win_set_cursor(ui_state.source_win, { line, 0 })
      return
    end
  end

  -- Wrap to last bookmark
  vim.api.nvim_win_set_cursor(ui_state.source_win, { ui_state.bookmarks[#ui_state.bookmarks], 0 })
end

-- Show list of bookmarks and allow selection
-- @param ui_state table: UI state object
function M.list_bookmarks(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  if #ui_state.bookmarks == 0 then
    vim.notify("No bookmarks set", vim.log.levels.WARN)
    return
  end

  -- Build list of bookmarks with preview
  local json = require("jsonlogs.json")
  local items = {}

  for _, line_num in ipairs(ui_state.bookmarks) do
    local lines = vim.api.nvim_buf_get_lines(ui_state.source_buf, line_num - 1, line_num, false)
    local preview = "???"

    if #lines > 0 then
      local parsed = json.parse(lines[1])
      if parsed then
        -- Show timestamp, level, and message if available
        local timestamp = json.get_field(parsed, "timestamp") or ""
        local level = json.get_field(parsed, "level") or ""
        local message = json.get_field(parsed, "message") or ""

        preview = string.format("[%s] %s: %s", timestamp, level, message)
        if #preview > 80 then
          preview = preview:sub(1, 77) .. "..."
        end
      else
        preview = lines[1]:sub(1, 80)
      end
    end

    table.insert(items, {
      line = line_num,
      text = string.format("Line %d: %s", line_num, preview),
    })
  end

  -- Use vim.ui.select to show bookmarks
  vim.ui.select(items, {
    prompt = "Bookmarks:",
    format_item = function(item)
      return item.text
    end,
  }, function(choice)
    if choice then
      vim.api.nvim_win_set_cursor(ui_state.source_win, { choice.line, 0 })
    end
  end)
end

-- Clear all bookmarks
-- @param ui_state table: UI state object
function M.clear_bookmarks(ui_state)
  if not ui_state.source_buf then
    return
  end

  ui_state.bookmarks = {}
  highlights.highlight_bookmarks(ui_state.source_buf, {})
  vim.notify("Cleared all bookmarks", vim.log.levels.INFO)
end

return M
