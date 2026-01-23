-- Statistics and analysis for JSONL logs
local json = require("jsonlogs.json")
local config = require("jsonlogs.config")

local M = {}

-- Analyze log file and generate statistics
-- @param buf number: Source buffer
-- @return table: Statistics object
function M.analyze(buf)
  local cfg = config.get()
  local total_lines = vim.api.nvim_buf_line_count(buf)
  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local stats = {
    total_entries = 0,
    parse_errors = 0,
    levels = {},
    fields = {},
    services = {},
    timestamps = {
      first = nil,
      last = nil,
      count = 0,
    },
  }

  for i, line in ipairs(all_lines) do
    if line ~= "" then
      local parsed, err = json.parse(line)

      if parsed then
        stats.total_entries = stats.total_entries + 1

        -- Count by level
        local level = json.get_field(parsed, cfg.navigation.error_field) or "unknown"
        stats.levels[level] = (stats.levels[level] or 0) + 1

        -- Count by service
        local service = json.get_field(parsed, "service")
        if service then
          stats.services[service] = (stats.services[service] or 0) + 1
        end

        -- Track timestamp range
        local timestamp = json.get_field(parsed, cfg.analysis.timestamp_field)
        if timestamp then
          stats.timestamps.count = stats.timestamps.count + 1
          if not stats.timestamps.first then
            stats.timestamps.first = timestamp
          end
          stats.timestamps.last = timestamp
        end

        -- Track all fields
        for field in pairs(parsed) do
          stats.fields[field] = (stats.fields[field] or 0) + 1
        end
      else
        stats.parse_errors = stats.parse_errors + 1
      end
    end
  end

  return stats
end

-- Format statistics for display
-- @param stats table: Statistics object
-- @return table: Array of formatted lines
function M.format_stats(stats)
  local lines = {
    "JSONL Log Statistics",
    string.rep("=", 50),
    "",
    string.format("Total Entries: %d", stats.total_entries),
    string.format("Parse Errors: %d", stats.parse_errors),
    "",
  }

  -- Levels
  if vim.tbl_count(stats.levels) > 0 then
    table.insert(lines, "Log Levels:")
    table.insert(lines, string.rep("-", 30))
    local level_list = {}
    for level, count in pairs(stats.levels) do
      table.insert(level_list, { level = level, count = count })
    end
    table.sort(level_list, function(a, b)
      return a.count > b.count
    end)

    for _, item in ipairs(level_list) do
      local percentage = (item.count / stats.total_entries) * 100
      table.insert(
        lines,
        string.format("  %-10s: %5d (%5.1f%%)", item.level, item.count, percentage)
      )
    end
    table.insert(lines, "")
  end

  -- Services
  if vim.tbl_count(stats.services) > 0 then
    table.insert(lines, "Services:")
    table.insert(lines, string.rep("-", 30))
    local service_list = {}
    for service, count in pairs(stats.services) do
      table.insert(service_list, { service = service, count = count })
    end
    table.sort(service_list, function(a, b)
      return a.count > b.count
    end)

    for _, item in ipairs(service_list) do
      local percentage = (item.count / stats.total_entries) * 100
      table.insert(
        lines,
        string.format("  %-15s: %5d (%5.1f%%)", item.service, item.count, percentage)
      )
    end
    table.insert(lines, "")
  end

  -- Timestamps
  if stats.timestamps.count > 0 then
    table.insert(lines, "Time Range:")
    table.insert(lines, string.rep("-", 30))
    table.insert(lines, string.format("  First: %s", stats.timestamps.first or "N/A"))
    table.insert(lines, string.format("  Last:  %s", stats.timestamps.last or "N/A"))
    table.insert(lines, string.format("  Entries with timestamps: %d", stats.timestamps.count))
    table.insert(lines, "")
  end

  -- Field frequency
  if vim.tbl_count(stats.fields) > 0 then
    table.insert(lines, "Common Fields:")
    table.insert(lines, string.rep("-", 30))
    local field_list = {}
    for field, count in pairs(stats.fields) do
      table.insert(field_list, { field = field, count = count })
    end
    table.sort(field_list, function(a, b)
      return a.count > b.count
    end)

    -- Show top 15 fields
    for i = 1, math.min(15, #field_list) do
      local item = field_list[i]
      local percentage = (item.count / stats.total_entries) * 100
      table.insert(
        lines,
        string.format("  %-20s: %5d (%5.1f%%)", item.field, item.count, percentage)
      )
    end
  end

  return lines
end

-- Show statistics in a floating window
-- @param ui_state table: UI state object
function M.show_stats(ui_state)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  -- Analyze logs
  vim.notify("Analyzing logs...", vim.log.levels.INFO)
  local stats = M.analyze(ui_state.source_buf)
  local lines = M.format_stats(stats)

  -- Create floating window
  local width = 60
  local height = math.min(#lines, 30)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "jsonlogs-stats")

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = " Statistics ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Close on q or ESC
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set("n", "<ESC>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })
end

return M
