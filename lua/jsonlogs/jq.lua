-- jq integration for advanced filtering
local json = require("jsonlogs.json")

local M = {}

-- Check if jq is available
-- @return boolean: True if jq is installed
function M.is_available()
  return vim.fn.executable("jq") == 1
end

-- Apply jq filter to a JSON line
-- @param line string: JSON line
-- @param filter string: jq filter expression
-- @param jq_path string: Path to jq binary
-- @return string|nil: Filtered result or nil if error
local function apply_jq_to_line(line, filter, jq_path)
  local temp_in = vim.fn.tempname()
  local temp_out = vim.fn.tempname()

  -- Write line to temp file
  local f = io.open(temp_in, "w")
  if not f then
    return nil
  end
  f:write(line)
  f:close()

  -- Run jq
  local cmd = string.format('%s %s %s > %s 2>/dev/null', jq_path, vim.fn.shellescape(filter), temp_in, temp_out)
  local exit_code = os.execute(cmd)

  os.remove(temp_in)

  if exit_code ~= 0 then
    os.remove(temp_out)
    return nil
  end

  -- Read output
  f = io.open(temp_out, "r")
  if not f then
    os.remove(temp_out)
    return nil
  end

  local result = f:read("*a")
  f:close()
  os.remove(temp_out)

  return result:gsub("\n$", "") -- Remove trailing newline
end

-- Apply jq filter to all logs
-- @param buf number: Source buffer
-- @param filter string: jq filter expression
-- @return table: Array of {line_num, result} for successful transformations
function M.apply_filter(buf, filter)
  if not M.is_available() then
    vim.notify("jq is not installed", vim.log.levels.ERROR)
    return {}
  end

  local cfg = require("jsonlogs.config").get()
  local jq_path = cfg.json.jq_path or "jq"
  local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local results = {}

  for i, line in ipairs(all_lines) do
    if line ~= "" then
      local result = apply_jq_to_line(line, filter, jq_path)
      if result and result ~= "" and result ~= "null" then
        table.insert(results, { line_num = i, result = result })
      end
    end
  end

  return results
end

-- Show jq filter results in new buffer
-- @param results table: Array of {line_num, result}
-- @param filter string: jq filter expression
function M.show_results(results, filter)
  if #results == 0 then
    vim.notify("No results from jq filter", vim.log.levels.WARN)
    return
  end

  -- Create new buffer
  local buf = vim.api.nvim_create_buf(true, false)
  local lines = {}

  for _, item in ipairs(results) do
    table.insert(lines, string.format("Line %d: %s", item.line_num, item.result))
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_name(buf, string.format("jq: %s", filter))
  vim.api.nvim_buf_set_option(buf, "filetype", "json")

  -- Open in new tab
  vim.cmd("tabnew")
  vim.api.nvim_win_set_buf(0, buf)

  vim.notify(string.format("jq filter: %d results", #results), vim.log.levels.INFO)
end

-- Prompt for jq filter
-- @param ui_state table: UI state object
function M.prompt_filter(ui_state)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  if not M.is_available() then
    vim.notify("jq is not installed", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({
    prompt = "jq filter (e.g., .user_id, select(.level==\"error\")): ",
  }, function(filter)
    if not filter or filter == "" then
      return
    end

    vim.notify("Applying jq filter...", vim.log.levels.INFO)
    local results = M.apply_filter(ui_state.source_buf, filter)
    M.show_results(results, filter)
  end)
end

return M
