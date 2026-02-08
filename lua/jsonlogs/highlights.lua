-- Syntax highlighting configuration for jsonlogs.nvim
local M = {}

-- Define highlight groups
function M.setup()
  -- Error indicators in source buffer
  vim.api.nvim_set_hl(0, "JsonLogsError", { fg = "#ff0000", bg = "#330000", bold = true })
  vim.api.nvim_set_hl(0, "JsonLogsWarn", { fg = "#ffaa00", bg = "#332200" })
  vim.api.nvim_set_hl(0, "JsonLogsFatal", { fg = "#ff0000", bg = "#660000", bold = true })
  vim.api.nvim_set_hl(0, "JsonLogsInfo", { fg = "#00aaff" })
  vim.api.nvim_set_hl(0, "JsonLogsDebug", { fg = "#888888" })

  -- Bookmark indicator
  vim.api.nvim_set_hl(0, "JsonLogsBookmark", { fg = "#ffff00", bold = true })

  -- Marked line for diff
  vim.api.nvim_set_hl(0, "JsonLogsMarked", { bg = "#003300" })

  -- Line numbers in compact mode
  vim.api.nvim_set_hl(0, "JsonLogsLineNr", { fg = "#555555" })

  -- Field highlighting
  vim.api.nvim_set_hl(0, "JsonLogsHighlightField", { bg = "#004444", bold = true })

  -- Cell truncation indicator
  vim.api.nvim_set_hl(0, "JsonLogsCellIndicator", { fg = "#ffaa00", bold = true })
end

-- Add level-based highlighting to source buffer
-- @param buf number: Buffer number
-- @param lines table: Array of JSON line strings
-- @param config table: Configuration
function M.highlight_source_buffer(buf, lines, config)
  local ns_id = vim.api.nvim_create_namespace("jsonlogs_levels")
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  local json = require("jsonlogs.json")
  local error_field = config.navigation.error_field
  local error_values = config.navigation.error_values

  for i, line in ipairs(lines) do
    local parsed = json.parse(line)
    if parsed then
      local level = json.get_field(parsed, error_field)
      if level then
        local hl_group = nil
        local level_lower = type(level) == "string" and string.lower(level) or ""

        if level_lower == "error" then
          hl_group = "JsonLogsError"
        elseif level_lower == "warn" or level_lower == "warning" then
          hl_group = "JsonLogsWarn"
        elseif level_lower == "fatal" then
          hl_group = "JsonLogsFatal"
        elseif level_lower == "info" then
          hl_group = "JsonLogsInfo"
        elseif level_lower == "debug" then
          hl_group = "JsonLogsDebug"
        end

        if hl_group then
          vim.api.nvim_buf_add_highlight(buf, ns_id, hl_group, i - 1, 0, -1)
        end
      end
    end
  end
end

-- Add bookmark highlighting
-- @param buf number: Buffer number
-- @param bookmarks table: Array of bookmarked line numbers
function M.highlight_bookmarks(buf, bookmarks)
  local ns_id = vim.api.nvim_create_namespace("jsonlogs_bookmarks")
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  for _, line_num in ipairs(bookmarks) do
    vim.api.nvim_buf_add_highlight(buf, ns_id, "JsonLogsBookmark", line_num - 1, 0, 5)

    -- Add virtual text marker
    vim.api.nvim_buf_set_extmark(buf, ns_id, line_num - 1, 0, {
      virt_text = { { "●", "JsonLogsBookmark" } },
      virt_text_pos = "overlay",
    })
  end
end

-- Highlight marked line for diff
-- @param buf number: Buffer number
-- @param line_num number: Line number
function M.highlight_marked_line(buf, line_num)
  local ns_id = vim.api.nvim_create_namespace("jsonlogs_marked")
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  if line_num then
    vim.api.nvim_buf_add_highlight(buf, ns_id, "JsonLogsMarked", line_num - 1, 0, -1)

    -- Add virtual text marker
    vim.api.nvim_buf_set_extmark(buf, ns_id, line_num - 1, 0, {
      virt_text = { { " [MARKED FOR DIFF]", "JsonLogsMarked" } },
      virt_text_pos = "eol",
    })
  end
end

-- Highlight specific field in preview buffer
-- @param buf number: Buffer number
-- @param field_name string: Name of field to highlight
function M.highlight_field_in_preview(buf, field_name)
  local ns_id = vim.api.nvim_create_namespace("jsonlogs_field_highlight")
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Pattern to match field name in JSON (handles quoted keys)
  local pattern = string.format('"%s"', field_name)

  for i, line in ipairs(lines) do
    local start_col = 1
    while true do
      local match_start, match_end = string.find(line, pattern, start_col, true)
      if not match_start then
        break
      end

      vim.api.nvim_buf_add_highlight(
        buf,
        ns_id,
        "JsonLogsHighlightField",
        i - 1,
        match_start - 1,
        match_end
      )

      start_col = match_end + 1
    end
  end
end

return M
