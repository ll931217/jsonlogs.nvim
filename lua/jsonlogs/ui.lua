-- UI module for split panel management
local json = require("jsonlogs.json")
local config = require("jsonlogs.config")
local highlights = require("jsonlogs.highlights")
local navigation = require("jsonlogs.navigation")
local bookmarks = require("jsonlogs.bookmarks")
local fold = require("jsonlogs.fold")
local diff = require("jsonlogs.diff")
local stats = require("jsonlogs.stats")
local tail = require("jsonlogs.tail")
local virtual = require("jsonlogs.virtual")
local table_mod = require("jsonlogs.table")
local stream = require("jsonlogs.stream")
local cache = require("jsonlogs.cache")

local M = {}

-- State
M.state = {
  source_buf = nil,      -- Buffer containing raw JSONL
  preview_buf = nil,     -- Buffer containing pretty-printed JSON
  source_win = nil,      -- Window ID for source
  preview_win = nil,     -- Window ID for preview
  current_line = 1,      -- Current line number in source
  total_lines = 0,       -- Total lines in source
  bookmarks = {},        -- Bookmarked line numbers
  marked_line = nil,     -- Line marked for diff
  compact_mode = false,  -- Compact display mode
  tail_mode = false,     -- Live tail mode
  filter = nil,          -- Active filter
  table_mode = false,    -- Table preview mode
  table_columns = nil,   -- Selected columns for table mode (nil = all)

  -- Streaming mode state
  streaming_mode = false,      -- Is streaming mode active?
  file_path = nil,             -- Original file path (for streaming)
  line_index = nil,            -- Line position index
  visible_range = {1, 1},      -- Currently loaded line range {start, end}
}

-- Create a scratch buffer
-- @param name string: Buffer name
-- @param filetype string: File type for syntax highlighting
-- @return number: Buffer number
local function create_scratch_buffer(name, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  return buf
end

-- Update the preview panel with current line's JSON
function M.update_preview()
  if not M.state.source_buf or not M.state.preview_buf then
    return
  end

  local cfg = config.get()
  local cursor_line = vim.api.nvim_win_get_cursor(M.state.source_win)[1]
  M.state.current_line = cursor_line

  -- In streaming mode, check if we need to load a new chunk
  if M.state.streaming_mode then
    local actual_line_num = M.state.visible_range[1] + cursor_line - 1

    -- Check if cursor is near the edge of the visible chunk
    local range = M.state.visible_range
    local chunk_size = cfg.streaming.chunk_size
    local edge_threshold = math.floor(chunk_size * 0.2)  -- Load new chunk when within 20% of edge

    if cursor_line <= edge_threshold then
      -- Near top edge, load previous chunk
      local new_start = math.max(1, range[1] - chunk_size)
      local new_end = math.min(M.state.total_lines, range[2] - chunk_size)
      if new_start >= 1 and new_start < range[1] then
        M.load_chunk(new_start, math.min(new_start + chunk_size - 1, M.state.total_lines))
        -- Adjust cursor to maintain position
        local new_cursor_line = cursor_line + (range[1] - new_start)
        vim.api.nvim_win_set_cursor(M.state.source_win, {new_cursor_line, 0})
      end
    elseif cursor_line >= (chunk_size - edge_threshold) then
      -- Near bottom edge, load next chunk
      local new_end = math.min(M.state.total_lines, range[2] + chunk_size)
      local new_start = math.max(1, new_end - chunk_size + 1)
      if new_end > range[2] then
        M.load_chunk(new_start, new_end)
        -- Adjust cursor to maintain position
        local new_cursor_line = cursor_line - (range[1] - new_start)
        vim.api.nvim_win_set_cursor(M.state.source_win, {new_cursor_line, 0})
      end
    end

    -- Update actual line number for preview
    actual_line_num = M.state.visible_range[1] + vim.api.nvim_win_get_cursor(M.state.source_win)[1] - 1
  end

  -- Get the current line
  local lines = vim.api.nvim_buf_get_lines(M.state.source_buf, cursor_line - 1, cursor_line, false)
  if #lines == 0 then
    return
  end

  local line = lines[1]

  -- Parse and pretty-print JSON
  local parsed, err = json.parse(line)
  local preview_lines

  if not parsed then
    preview_lines = {
      "Error parsing JSON:",
      "",
      err,
      "",
      "Raw line:",
      line,
    }
  else
    if M.state.table_mode then
      -- Table mode: show all entries as table rows
      if M.state.streaming_mode then
        -- In streaming mode, show warning about pagination
        local table_lines = M._get_streaming_table_lines(cfg)
        preview_lines = table_lines
        table.insert(preview_lines, "")
        local actual_line = M.state.visible_range[1] + cursor_line - 1
        table.insert(preview_lines, string.format("→ Current row: %d (showing chunk %d-%d)", actual_line, M.state.visible_range[1], M.state.visible_range[2]))
      else
        local all_lines = vim.api.nvim_buf_get_lines(M.state.source_buf, 0, -1, false)
        preview_lines = table_mod.format_table(all_lines, M.state.table_columns, cfg)
        table.insert(preview_lines, "")
        table.insert(preview_lines, string.format("→ Current row: %d", cursor_line))
      end
    elseif M.state.compact_mode then
      -- Compact mode: show only selected fields
      preview_lines = M.get_compact_view(parsed, cfg)
    else
      -- Full pretty-print
      preview_lines, err = json.pretty_print(parsed, cfg.json)
      if err then
        preview_lines = { "Error formatting JSON: " .. err }
      end
    end
  end

  -- Update preview buffer
  vim.api.nvim_buf_set_option(M.state.preview_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.preview_buf, 0, -1, false, preview_lines)
  vim.api.nvim_buf_set_option(M.state.preview_buf, "modifiable", false)

  -- Update status line
  M.update_status()
end

-- Get table lines for streaming mode (paginated view)
-- @param cfg table: Configuration
-- @return table: Array of formatted table lines
function M._get_streaming_table_lines(cfg)
  local header = {
    string.format("─ Table View (showing chunk %d-%d of %d entries) ─",
      M.state.visible_range[1], M.state.visible_range[2], M.state.total_lines),
    "Use navigation to view more entries",
    "",
  }

  local chunk_lines = vim.api.nvim_buf_get_lines(M.state.source_buf, 0, -1, false)
  local table_lines = table_mod.format_table(chunk_lines, M.state.table_columns, cfg)

  return vim.list_extend(header, table_lines)
end

-- Get compact view of JSON object
-- @param obj table: Parsed JSON object
-- @param cfg table: Configuration
-- @return table: Array of formatted lines
function M.get_compact_view(obj, cfg)
  local lines = {}
  local fields = cfg.display.compact_fields or { "timestamp", "level", "message" }

  for _, field in ipairs(fields) do
    local value = json.get_field(obj, field)
    if value ~= nil then
      local value_str = type(value) == "string" and value or vim.inspect(value)
      table.insert(lines, string.format("%s: %s", field, value_str))
    end
  end

  if #lines == 0 then
    return { "No compact fields found", "", "Available fields:", vim.inspect(vim.tbl_keys(obj)) }
  end

  return lines
end

-- Update status line
function M.update_status()
  if not M.state.source_win then
    return
  end

  local status
  if M.state.streaming_mode then
    local range = M.state.visible_range
    status = string.format("Lines %d-%d of %d", range[1], range[2], M.state.total_lines)
  else
    status = string.format("Line %d/%d", M.state.current_line, M.state.total_lines)
  end

  if M.state.table_mode then
    status = status .. " [TABLE]"
  elseif M.state.compact_mode then
    status = status .. " [COMPACT]"
  end

  if M.state.tail_mode then
    status = status .. " [TAIL]"
  end

  if M.state.streaming_mode then
    status = status .. " [STREAMING]"
  end

  if M.state.filter then
    status = status .. string.format(" [FILTER: %s=%s]", M.state.filter.field, M.state.filter.value)
  end

  vim.api.nvim_win_set_option(M.state.preview_win, "statusline", status)
end

-- Open the split panel viewer
-- @param source_file string: Path to the JSONL file
function M.open(source_file)
  local cfg = config.get()

  -- Get or create source buffer
  if source_file then
    M.state.source_buf = vim.fn.bufnr(source_file, true)
    M.state.file_path = vim.fn.expand(source_file)
    vim.fn.bufload(M.state.source_buf)
  else
    M.state.source_buf = vim.api.nvim_get_current_buf()
    M.state.file_path = vim.api.nvim_buf_get_name(M.state.source_buf)
  end

  -- Determine if we should use streaming mode
  local should_stream = M._should_enable_streaming(M.state.file_path, cfg)

  if should_stream then
    M.enable_streaming_mode(M.state.file_path, cfg)
  else
    -- Use existing non-streaming behavior
    M.state.total_lines = vim.api.nvim_buf_line_count(M.state.source_buf)
  end

  -- Create preview buffer
  M.state.preview_buf = create_scratch_buffer("JsonLogs Preview", "json")

  -- Enable folding in preview buffer
  fold.enable_folding(M.state.preview_buf)

  -- Create windows
  local current_win = vim.api.nvim_get_current_win()

  if cfg.layout.position == "right" then
    -- Vertical split
    vim.cmd("vsplit")
    M.state.preview_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.state.preview_win, M.state.preview_buf)
    vim.api.nvim_win_set_width(M.state.preview_win, cfg.layout.width)

    -- Move to source window
    vim.cmd("wincmd h")
    M.state.source_win = vim.api.nvim_get_current_win()
    if source_file then
      vim.api.nvim_win_set_buf(M.state.source_win, M.state.source_buf)
    end
  else
    -- Horizontal split
    vim.cmd("split")
    M.state.preview_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(M.state.preview_win, M.state.preview_buf)
    vim.api.nvim_win_set_height(M.state.preview_win, cfg.layout.height)

    -- Move to source window
    vim.cmd("wincmd k")
    M.state.source_win = vim.api.nvim_get_current_win()
    if source_file then
      vim.api.nvim_win_set_buf(M.state.source_win, M.state.source_buf)
    end
  end

  -- Initialize cache with configured size
  cache.setup({ max_size = cfg.streaming.cache_size })

  -- Initialize highlights
  highlights.setup()

  -- Apply highlighting to source buffer
  if M.state.streaming_mode then
    -- For streaming mode, highlight only the visible chunk
    local chunk_lines = vim.api.nvim_buf_get_lines(M.state.source_buf, 0, -1, false)
    highlights.highlight_source_buffer(M.state.source_buf, chunk_lines, cfg)
  else
    local all_lines = vim.api.nvim_buf_get_lines(M.state.source_buf, 0, -1, false)
    highlights.highlight_source_buffer(M.state.source_buf, all_lines, cfg)
  end

  -- Add virtual text annotations (skip in streaming mode for performance)
  if not M.state.streaming_mode then
    virtual.add_virtual_text(M.state.source_buf, cfg)
  end

  -- Set up keybinds
  M.setup_keybinds()

  -- Set up auto-update on cursor move
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = M.state.source_buf,
    callback = function()
      M.update_preview()
    end,
  })

  -- Initial preview update
  M.update_preview()
end

-- Determine if streaming mode should be enabled
-- @param file_path string: Path to the file
-- @param cfg table: Configuration
-- @return boolean: True if streaming should be enabled
function M._should_enable_streaming(file_path, cfg)
  local stream_cfg = cfg.streaming

  -- Check if streaming is explicitly disabled
  if stream_cfg.enabled == false then
    return false
  end

  -- Check if streaming is explicitly enabled
  if stream_cfg.enabled == true then
    return true
  end

  -- Auto mode: check file size
  local file_size_mb = stream.get_file_size_mb(file_path)
  return file_size_mb > stream_cfg.threshold_mb
end

-- Enable streaming mode
-- @param file_path string: Path to the file
-- @param cfg table: Configuration
function M.enable_streaming_mode(file_path, cfg)
  cfg = cfg or config.get()

  M.state.streaming_mode = true
  M.state.file_path = file_path

  -- Show progress if enabled
  if cfg.streaming.show_progress then
    vim.notify("Building line index...", vim.log.levels.INFO)
  end

  -- Build line position index
  local progress_callback
  if cfg.streaming.show_progress then
    progress_callback = function(current, total, percent)
      vim.notify(string.format("Indexing: %d%% (%d/%d lines)", percent, current, total), vim.log.levels.INFO)
    end
  end

  M.state.line_index = stream.build_index(file_path, progress_callback)

  if not M.state.line_index then
    vim.notify("Failed to build line index, falling back to non-streaming mode", vim.log.levels.WARN)
    M.state.streaming_mode = false
    return
  end

  M.state.total_lines = M.state.line_index.total_lines

  -- Load initial chunk
  local chunk_size = cfg.streaming.chunk_size
  local initial_end = math.min(chunk_size, M.state.total_lines)
  M.load_chunk(1, initial_end)

  if cfg.streaming.show_progress then
    vim.notify(string.format("Streaming mode enabled: %d lines indexed", M.state.total_lines), vim.log.levels.INFO)
  end
end

-- Load a chunk of lines into the source buffer
-- @param start_line number: 1-indexed start line
-- @param end_line number: 1-indexed end line (inclusive)
function M.load_chunk(start_line, end_line)
  if not M.state.streaming_mode or not M.state.file_path then
    return
  end

  local lines = stream.get_lines(M.state.file_path, start_line, end_line)
  if not lines then
    vim.notify("Failed to load chunk", vim.log.levels.ERROR)
    return
  end

  -- Update buffer with chunk
  vim.api.nvim_buf_set_option(M.state.source_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.source_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.source_buf, "modifiable", false)

  M.state.visible_range = {start_line, end_line}
end

-- Set up keybinds for the viewer
function M.setup_keybinds()
  local cfg = config.get()
  local keys = cfg.keys

  -- Quit
  vim.keymap.set("n", keys.quit, function()
    M.close()
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  vim.keymap.set("n", keys.quit, function()
    M.close()
  end, { buffer = M.state.preview_buf, noremap = true, silent = true })

  -- Yank JSON
  vim.keymap.set("n", keys.yank_json, function()
    M.yank_json()
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Compact mode toggle
  vim.keymap.set("n", keys.compact_mode, function()
    M.toggle_compact_mode()
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Navigation: Error jumping
  vim.keymap.set("n", keys.next_error, function()
    navigation.jump_to_next_error(M.state)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  vim.keymap.set("n", keys.prev_error, function()
    navigation.jump_to_prev_error(M.state)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Navigation: Search
  vim.keymap.set("n", keys.search, function()
    navigation.prompt_search(M.state)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Bookmarks
  vim.keymap.set("n", keys.bookmark, function()
    bookmarks.toggle_bookmark(M.state)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  vim.keymap.set("n", keys.list_bookmarks, function()
    bookmarks.list_bookmarks(M.state)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Diff view
  vim.keymap.set("n", keys.diff_view, function()
    if M.state.marked_line then
      diff.show_diff(M.state)
    else
      diff.mark_for_diff(M.state)
    end
  end, { buffer = M.state.source_buf, noremap = true, silent = true, desc = "Mark/show diff" })

  -- Fold toggle in preview buffer
  vim.keymap.set("n", keys.toggle_fold, function()
    fold.toggle_fold_at_cursor(M.state.preview_buf)
  end, { buffer = M.state.preview_buf, noremap = true, silent = true })

  -- Statistics
  vim.keymap.set("n", keys.stats, function()
    stats.show_stats(M.state)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Tail mode
  vim.keymap.set("n", keys.tail_mode, function()
    tail.toggle_tail(M.state)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Table mode toggle
  vim.keymap.set("n", keys.table_mode, function()
    M.toggle_table_mode()
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Column filter modal
  vim.keymap.set("n", keys.table_columns, function()
    table_mod.show_column_filter(M.state, function(columns)
      M.state.table_columns = columns
      M.update_preview()
    end)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- Telescope picker (if available)
  vim.keymap.set("n", "<C-f>", function()
    local telescope_mod = require("jsonlogs.telescope")
    if telescope_mod.is_available() then
      telescope_mod.open_picker(M.state)
    else
      vim.notify("Telescope is not installed", vim.log.levels.WARN)
    end
  end, { buffer = M.state.source_buf, noremap = true, silent = true })

  -- jq filter (if available)
  vim.keymap.set("n", "J", function()
    local jq_mod = require("jsonlogs.jq")
    jq_mod.prompt_filter(M.state)
  end, { buffer = M.state.source_buf, noremap = true, silent = true })
end

-- Close the viewer
function M.close()
  if M.state.preview_win and vim.api.nvim_win_is_valid(M.state.preview_win) then
    vim.api.nvim_win_close(M.state.preview_win, true)
  end

  -- Clear stream cache if in streaming mode
  if M.state.streaming_mode and M.state.file_path then
    stream.clear_cache(M.state.file_path)
  end

  -- Reset state
  M.state.source_buf = nil
  M.state.preview_buf = nil
  M.state.source_win = nil
  M.state.preview_win = nil
  M.state.current_line = 1
  M.state.bookmarks = {}
  M.state.marked_line = nil
  M.state.compact_mode = false
  M.state.tail_mode = false
  M.state.filter = nil
  M.state.table_mode = false
  M.state.table_columns = nil

  -- Reset streaming state
  M.state.streaming_mode = false
  M.state.file_path = nil
  M.state.line_index = nil
  M.state.visible_range = {1, 1}
end

-- Yank formatted JSON to clipboard
function M.yank_json()
  if not M.state.preview_buf then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(M.state.preview_buf, 0, -1, false)
  local content = table.concat(lines, "\n")
  vim.fn.setreg("+", content)
  vim.notify("Copied formatted JSON to clipboard", vim.log.levels.INFO)
end

-- Toggle compact mode
function M.toggle_compact_mode()
  M.state.compact_mode = not M.state.compact_mode
  M.update_preview()
  local mode = M.state.compact_mode and "ON" or "OFF"
  vim.notify("Compact mode: " .. mode, vim.log.levels.INFO)
end

-- Toggle table mode
function M.toggle_table_mode()
  M.state.table_mode = not M.state.table_mode

  if M.state.table_mode then
    -- Disable compact mode when enabling table mode
    M.state.compact_mode = false

    -- Discover columns on first activation if not already set
    if not M.state.table_columns then
      local source = M.state.streaming_mode and M.state.file_path or M.state.source_buf
      M.state.table_columns = table_mod.discover_all_columns(source, M.state.streaming_mode)
    end
  end

  M.update_preview()
  local mode = M.state.table_mode and "ON" or "OFF"
  vim.notify("Table mode: " .. mode, vim.log.levels.INFO)
end

-- Check if viewer is open
-- @return boolean: True if viewer is active
function M.is_open()
  return M.state.source_buf ~= nil and M.state.preview_buf ~= nil
end

return M
