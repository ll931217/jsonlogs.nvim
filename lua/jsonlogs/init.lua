-- Main entry point for jsonlogs.nvim
local config = require("jsonlogs.config")
local ui = require("jsonlogs.ui")

local M = {}

-- Setup function (called by lazy.nvim or user)
-- @param opts table: User configuration options
function M.setup(opts)
  -- Merge user config with defaults
  config.setup(opts or {})

  -- Register commands
  M.register_commands()

  -- Set up auto-open for .jsonl files if enabled
  local cfg = config.get()
  if cfg.auto_open then
    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
      pattern = "*.jsonl",
      callback = function()
        -- Delay to ensure buffer is fully loaded
        vim.defer_fn(function()
          if not ui.is_open() then
            M.open()
          end
        end, 100)
      end,
    })
  end
end

-- Register plugin commands
function M.register_commands()
  -- Main viewer command
  vim.api.nvim_create_user_command("JsonLogs", function(opts)
    M.open(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    complete = "file",
    desc = "Open JSONL log viewer",
  })

  -- Navigate to specific line
  vim.api.nvim_create_user_command("JsonLogsGoto", function(opts)
    local line = tonumber(opts.args)
    if line then
      M.goto_line(line)
    else
      vim.notify("Invalid line number", vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    desc = "Go to specific line in JSONL viewer",
  })

  -- Close viewer
  vim.api.nvim_create_user_command("JsonLogsClose", function()
    M.close()
  end, {
    nargs = 0,
    desc = "Close JSONL viewer",
  })

  -- Statistics
  vim.api.nvim_create_user_command("JsonLogsStats", function()
    if ui.is_open() then
      local stats = require("jsonlogs.stats")
      stats.show_stats(ui.state)
    else
      vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    end
  end, {
    nargs = 0,
    desc = "Show log statistics",
  })

  -- Filter by time range
  vim.api.nvim_create_user_command("JsonLogsFilter", function()
    if ui.is_open() then
      local filter = require("jsonlogs.filter")
      filter.prompt_time_range_filter(ui.state)
    else
      vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    end
  end, {
    nargs = 0,
    desc = "Filter logs by time range",
  })

  -- Filter by level
  vim.api.nvim_create_user_command("JsonLogsFilterLevel", function()
    if ui.is_open() then
      local filter = require("jsonlogs.filter")
      filter.prompt_level_filter(ui.state)
    else
      vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    end
  end, {
    nargs = 0,
    desc = "Filter logs by level",
  })

  -- Export
  vim.api.nvim_create_user_command("JsonLogsExport", function(opts)
    if ui.is_open() then
      local export = require("jsonlogs.export")
      export.export_current_view(ui.state)
    else
      vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    complete = "file",
    desc = "Export current view to file",
  })

  -- Tail mode
  vim.api.nvim_create_user_command("JsonLogsTail", function()
    if ui.is_open() then
      local tail = require("jsonlogs.tail")
      tail.toggle_tail(ui.state)
    else
      vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    end
  end, {
    nargs = 0,
    desc = "Toggle live tail mode",
  })

  -- Table mode column filter
  vim.api.nvim_create_user_command("JsonLogsTableColumns", function()
    if ui.is_open() then
      local table_mod = require("jsonlogs.table")
      table_mod.show_column_filter(ui.state, function(columns)
        ui.state.table_columns = columns
        ui.update_preview()
      end)
    else
      vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    end
  end, {
    nargs = 0,
    desc = "Filter table columns",
  })

  -- jq filter
  vim.api.nvim_create_user_command("JsonLogsJq", function(opts)
    if ui.is_open() then
      local jq = require("jsonlogs.jq")
      if opts.args ~= "" then
        local results = jq.apply_filter(ui.state.source_buf, opts.args)
        jq.show_results(results, opts.args)
      else
        jq.prompt_filter(ui.state)
      end
    else
      vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    end
  end, {
    nargs = "?",
    desc = "Apply jq filter to logs",
  })

  -- Telescope picker
  vim.api.nvim_create_user_command("JsonLogsTelescope", function()
    if ui.is_open() then
      local telescope = require("jsonlogs.telescope")
      telescope.open_picker(ui.state)
    else
      vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    end
  end, {
    nargs = 0,
    desc = "Open Telescope picker for logs",
  })
end

-- Open the viewer
-- @param file string|nil: Optional file path
function M.open(file)
  ui.open(file)
end

-- Close the viewer
function M.close()
  ui.close()
end

-- Go to specific line
-- @param line number: Line number to jump to
function M.goto_line(line)
  if not ui.is_open() then
    vim.notify("JsonLogs viewer is not open", vim.log.levels.ERROR)
    return
  end

  if ui.state.source_win then
    vim.api.nvim_win_set_cursor(ui.state.source_win, { line, 0 })
    ui.update_preview()
  end
end

return M
