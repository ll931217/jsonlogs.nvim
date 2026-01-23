-- Export functionality for filtered logs
local json = require("jsonlogs.json")

local M = {}

-- Export lines to file
-- @param lines table: Array of line strings
-- @param filepath string: Destination file path
-- @return boolean: Success status
function M.export_to_file(lines, filepath)
  local file, err = io.open(filepath, "w")
  if not file then
    vim.notify("Failed to open file: " .. err, vim.log.levels.ERROR)
    return false
  end

  for _, line in ipairs(lines) do
    file:write(line .. "\n")
  end

  file:close()
  return true
end

-- Export current buffer
-- @param ui_state table: UI state object
function M.export_current_buffer(ui_state)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({
    prompt = "Export to file: ",
    default = "exported.jsonl",
  }, function(filepath)
    if not filepath or filepath == "" then
      return
    end

    local all_lines = vim.api.nvim_buf_get_lines(ui_state.source_buf, 0, -1, false)

    if M.export_to_file(all_lines, filepath) then
      vim.notify(string.format("Exported %d lines to %s", #all_lines, filepath), vim.log.levels.INFO)
    end
  end)
end

-- Export filtered logs
-- @param matches table: Array of {line_num, line_content}
-- @param ui_state table: UI state object (optional, for file prompt)
function M.export_filtered(matches)
  if #matches == 0 then
    vim.notify("No entries to export", vim.log.levels.WARN)
    return
  end

  vim.ui.input({
    prompt = "Export to file: ",
    default = "filtered.jsonl",
  }, function(filepath)
    if not filepath or filepath == "" then
      return
    end

    local lines = {}
    for _, match in ipairs(matches) do
      table.insert(lines, match.content)
    end

    if M.export_to_file(lines, filepath) then
      vim.notify(string.format("Exported %d entries to %s", #lines, filepath), vim.log.levels.INFO)
    end
  end)
end

-- Export statistics to file
-- @param stats table: Statistics object
-- @param lines table: Formatted statistics lines
function M.export_stats(stats, lines)
  vim.ui.input({
    prompt = "Export statistics to: ",
    default = "stats.txt",
  }, function(filepath)
    if not filepath or filepath == "" then
      return
    end

    if M.export_to_file(lines, filepath) then
      vim.notify(string.format("Exported statistics to %s", filepath), vim.log.levels.INFO)
    end
  end)
end

-- Export current view (with filters applied)
-- @param ui_state table: UI state object
function M.export_current_view(ui_state)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  -- If filter is active, export filtered results
  if ui_state.filter then
    local filter_module = require("jsonlogs.filter")
    local matches = filter_module.filter_by_field(
      ui_state.source_buf,
      ui_state.filter.field,
      ui_state.filter.value
    )
    M.export_filtered(matches)
  else
    -- Export entire buffer
    M.export_current_buffer(ui_state)
  end
end

return M
