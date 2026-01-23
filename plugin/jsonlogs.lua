-- Auto-commands for jsonlogs.nvim
-- This file is loaded automatically by Neovim

-- Prevent loading twice
if vim.g.loaded_jsonlogs then
  return
end
vim.g.loaded_jsonlogs = 1

-- Auto-setup with defaults if user hasn't called setup()
-- This ensures the plugin works even without explicit configuration
vim.defer_fn(function()
  -- Check if jsonlogs has been set up
  local ok, jsonlogs = pcall(require, "jsonlogs")
  if ok and not vim.g.jsonlogs_setup_done then
    -- Setup with defaults (user can override later)
    jsonlogs.setup({})
    vim.g.jsonlogs_setup_done = 1
  end
end, 0)
