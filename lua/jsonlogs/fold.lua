-- Folding support for JSON preview
local M = {}

-- Enable folding for JSON preview buffer
-- @param buf number: Buffer number
function M.enable_folding(buf)
  -- Use indentation-based folding for JSON
  vim.api.nvim_buf_set_option(buf, "foldmethod", "indent")
  vim.api.nvim_buf_set_option(buf, "foldlevel", 99) -- Start with all folds open
  vim.api.nvim_buf_set_option(buf, "foldlevelstart", 99)

  -- Set fold text to show what's folded
  vim.api.nvim_buf_set_option(
    buf,
    "foldtext",
    "v:lua.require'jsonlogs.fold'.fold_text()"
  )
end

-- Custom fold text to show folded content summary
-- @return string: Fold text
function M.fold_text()
  local line = vim.fn.getline(vim.v.foldstart)
  local line_count = vim.v.foldend - vim.v.foldstart + 1

  -- Extract the key if it's a JSON object/array
  local key = line:match('"([^"]+)":') or ""
  local type_indicator = ""

  if line:match("{%s*$") then
    type_indicator = "{...}"
  elseif line:match("%[%s*$") then
    type_indicator = "[...]"
  end

  local summary = key ~= "" and string.format('"%s": %s', key, type_indicator) or type_indicator
  return string.format("+-- %s (%d lines) ", summary, line_count)
end

-- Toggle fold at cursor position
-- @param buf number: Buffer number
function M.toggle_fold_at_cursor(buf)
  local current_win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(current_win) ~= buf then
    return
  end

  local fold_level = vim.fn.foldlevel(".")
  if fold_level == 0 then
    vim.notify("No fold at cursor", vim.log.levels.WARN)
    return
  end

  if vim.fn.foldclosed(".") == -1 then
    -- Fold is open, close it
    vim.cmd("normal! zc")
  else
    -- Fold is closed, open it
    vim.cmd("normal! zo")
  end
end

-- Open all folds
-- @param buf number: Buffer number
function M.open_all_folds(buf)
  vim.api.nvim_buf_set_option(buf, "foldlevel", 99)
end

-- Close all folds
-- @param buf number: Buffer number
function M.close_all_folds(buf)
  vim.api.nvim_buf_set_option(buf, "foldlevel", 0)
end

return M
