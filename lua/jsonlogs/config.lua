-- Configuration module for jsonlogs.nvim
local M = {}

-- Default configuration
M.defaults = {
  -- Keybind prefix (can be customized via lazy.nvim opts)
  prefix = "<leader>jl",

  -- Auto-open viewer for .jsonl files
  auto_open = true,

  -- Panel layout
  layout = {
    position = "right", -- Preview panel position: "right" or "bottom"
    width = 80,         -- Preview panel width (for vertical split)
    height = 20,        -- Preview panel height (for horizontal split)
  },

  -- JSON pretty-print settings
  json = {
    indent = 2,
    use_jq_fallback = true, -- Use jq for large objects if available
    jq_path = "jq",         -- Path to jq binary
  },

  -- Navigation settings
  navigation = {
    error_field = "level",  -- Field to check for error detection
    error_values = { "error", "ERROR", "fatal", "FATAL" },
  },

  -- Display settings
  display = {
    show_line_numbers = true,
    syntax_highlighting = true,
    compact_fields = { "timestamp", "level", "message" }, -- Fields for compact mode
    table_max_col_width = 30,      -- Max column width in table mode
    table_null_placeholder = "-",  -- Placeholder for missing values in table mode
  },

  -- Analysis settings
  analysis = {
    timestamp_field = "timestamp", -- Field containing timestamp
    timestamp_formats = {          -- Supported timestamp formats
      "%Y-%m-%dT%H:%M:%S",
      "%Y-%m-%d %H:%M:%S",
      "iso8601",
    },
  },

  -- Advanced settings
  advanced = {
    tail_update_interval = 100, -- Milliseconds between tail updates
    max_preview_size = 10000,   -- Max chars for pretty-print (fallback to jq)
    virtual_text = true,        -- Enable virtual text annotations
  },

  -- Keybinds (can be overridden via lazy.nvim keys)
  keys = {
    quit = "q",
    next_entry = "j",
    prev_entry = "k",
    next_error = "]e",
    prev_error = "[e",
    first_entry = "gg",
    last_entry = "G",
    toggle_fold = "<CR>",
    yank_json = "y",
    bookmark = "m",
    list_bookmarks = "'",
    search = "/",
    compact_mode = "c",
    diff_view = "d",
    tail_mode = "t",
    stats = "s",
    table_mode = "T",      -- Toggle table preview mode
    table_columns = "C",   -- Open column filter modal
  },
}

-- Current configuration (merged with user opts)
M.options = vim.deepcopy(M.defaults)

-- Merge user configuration with defaults
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  return M.options
end

-- Get current configuration
function M.get()
  return M.options
end

return M
