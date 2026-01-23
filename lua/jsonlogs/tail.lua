-- Live tail mode for watching log files
local M = {}

M.timer = nil
M.last_line_count = 0

-- Start tail mode
-- @param ui_state table: UI state object
function M.start_tail(ui_state)
  if not ui_state.source_buf or not ui_state.source_win then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  if ui_state.tail_mode then
    vim.notify("Tail mode already active", vim.log.levels.WARN)
    return
  end

  ui_state.tail_mode = true
  M.last_line_count = vim.api.nvim_buf_line_count(ui_state.source_buf)

  local cfg = require("jsonlogs.config").get()
  local interval = cfg.advanced.tail_update_interval or 100

  -- Start timer to check for new lines
  M.timer = vim.loop.new_timer()
  M.timer:start(
    0,
    interval,
    vim.schedule_wrap(function()
      if not ui_state.tail_mode or not vim.api.nvim_buf_is_valid(ui_state.source_buf) then
        M.stop_tail(ui_state)
        return
      end

      -- Reload buffer from disk
      vim.api.nvim_buf_call(ui_state.source_buf, function()
        vim.cmd("checktime")
      end)

      local current_line_count = vim.api.nvim_buf_line_count(ui_state.source_buf)

      if current_line_count > M.last_line_count then
        -- New lines added
        M.last_line_count = current_line_count

        -- Reapply highlighting
        local highlights = require("jsonlogs.highlights")
        local all_lines = vim.api.nvim_buf_get_lines(ui_state.source_buf, 0, -1, false)
        highlights.highlight_source_buffer(ui_state.source_buf, all_lines, cfg)

        -- Update total lines
        ui_state.total_lines = current_line_count

        -- Jump to last line if enabled
        vim.api.nvim_win_set_cursor(ui_state.source_win, { current_line_count, 0 })
      end
    end)
  )

  vim.notify("Tail mode started", vim.log.levels.INFO)
end

-- Stop tail mode
-- @param ui_state table: UI state object
function M.stop_tail(ui_state)
  if M.timer then
    M.timer:stop()
    M.timer:close()
    M.timer = nil
  end

  ui_state.tail_mode = false
  vim.notify("Tail mode stopped", vim.log.levels.INFO)
end

-- Toggle tail mode
-- @param ui_state table: UI state object
function M.toggle_tail(ui_state)
  if ui_state.tail_mode then
    M.stop_tail(ui_state)
  else
    M.start_tail(ui_state)
  end
end

return M
