-- Progress UI module for showing long-running operations
local M = {}

-- Active progress windows
local active_windows = {}

-- Show progress in a floating window
-- @param title string: Title of the progress operation
-- @param current number: Current progress value
-- @param total number: Total value (target)
-- @return table: Progress window object with update() and close() methods
function M.show_progress(title, current, total)
  -- Close any existing progress for this title
  M.close_progress(title)

  local percent = total > 0 and math.floor((current / total) * 100) or 0
  local buf = vim.api.nvim_create_buf(false, true)

  -- Calculate window size
  local width = 40
  local height = 5

  -- Create progress lines
  local lines = {
    title,
    string.rep("─", width - 2),
    "",
    M._create_progress_bar(width - 4, percent),
    string.format("%d%% (%d/%d)", percent, current, total),
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Create floating window
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, false, opts)

  -- Store progress window info
  active_windows[title] = {
    buf = buf,
    win = win,
    title = title,
    current = current,
    total = total,
  }

  -- Return control object
  return {
    update = function(new_current)
      return M.update_progress(title, new_current)
    end,

    close = function()
      return M.close_progress(title)
    end,
  }
end

-- Update an existing progress window
-- @param title string: Title of the progress operation
-- @param current number: New current progress value
-- @return boolean: True if update succeeded, false if window not found
function M.update_progress(title, current)
  local progress = active_windows[title]
  if not progress then
    return false
  end

  if not vim.api.nvim_win_is_valid(progress.win) then
    active_windows[title] = nil
    return false
  end

  progress.current = current
  local total = progress.total
  local width = vim.api.nvim_win_get_width(progress.win)
  local percent = total > 0 and math.floor((current / total) * 100) or 0

  local lines = {
    progress.title,
    string.rep("─", width - 2),
    "",
    M._create_progress_bar(width - 4, percent),
    string.format("%d%% (%d/%d)", percent, current, total),
  }

  vim.api.nvim_buf_set_option(progress.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(progress.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(progress.buf, "modifiable", false)

  -- Auto-close when complete
  if current >= total then
    M.close_progress(title)
  end

  return true
end

-- Close a progress window
-- @param title string: Title of the progress operation
-- @return boolean: True if closed, false if not found
function M.close_progress(title)
  local progress = active_windows[title]
  if not progress then
    return false
  end

  if vim.api.nvim_win_is_valid(progress.win) then
    vim.api.nvim_win_close(progress.win, true)
  end

  active_windows[title] = nil
  return true
end

-- Create a visual progress bar
-- @param width number: Width of the progress bar in characters
-- @param percent number: Percentage complete (0-100)
-- @return string: Progress bar string
function M._create_progress_bar(width, percent)
  local filled = math.floor((percent / 100) * width)
  local empty = width - filled

  if filled == 0 then
    return "[" .. string.rep(" ", width) .. "]"
  elseif filled >= width then
    return "[" .. string.rep("=", width) .. "]"
  else
    return "[" .. string.rep("=", filled) .. string.rep(" ", empty) .. "]"
  end
end

-- Show a simple notification with progress
-- @param title string: Title of the operation
-- @param current number: Current progress value
-- @param total number: Total value
function M.notify_progress(title, current, total)
  local percent = total > 0 and math.floor((current / total) * 100) or 0
  local message = string.format("%s: %d%% (%d/%d)", title, percent, current, total)
  vim.notify(message, vim.log.levels.INFO)
end

-- Create a spinner for operations with unknown duration
-- @param title string: Title of the operation
-- @param frames table: Array of spinner frames (optional)
-- @return table: Spinner object with update() and close() methods
function M.show_spinner(title, frames)
  frames = frames or { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

  local buf = vim.api.nvim_create_buf(false, true)

  local lines = {
    title,
    string.rep("─", 20),
    "",
    frames[1],
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local opts = {
    relative = "editor",
    width = 22,
    height = 4,
    col = (vim.o.columns - 22) / 2,
    row = (vim.o.lines - 4) / 2,
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, false, opts)
  local frame_index = 1

  -- Start timer to animate spinner
  local timer = vim.loop.new_timer()
  timer:start(100, 100, vim.schedule_wrap(function()
    if not vim.api.nvim_win_is_valid(win) then
      timer:close()
      return
    end

    frame_index = (frame_index % #frames) + 1

    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 3, 4, false, { frames[frame_index] })
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end))

  return {
    update = function(message)
      if vim.api.nvim_win_is_valid(win) then
        local new_lines = {
          title,
          string.rep("─", 20),
          "",
          frames[frame_index],
          "",
          message or "",
        }
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
      end
    end,

    close = function()
      timer:close()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  }
end

-- Close all active progress windows
function M.close_all()
  for title, _ in pairs(active_windows) do
    M.close_progress(title)
  end
end

return M
