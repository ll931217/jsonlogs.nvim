-- Telescope integration for fuzzy searching logs
local M = {}

-- Check if Telescope is available
-- @return boolean: True if Telescope is installed
function M.is_available()
  return pcall(require, "telescope")
end

-- Create Telescope picker for JSONL logs
-- @param ui_state table: UI state object
function M.open_picker(ui_state)
  if not ui_state.source_buf then
    vim.notify("Viewer not open", vim.log.levels.ERROR)
    return
  end

  if not M.is_available() then
    vim.notify("Telescope is not installed", vim.log.levels.WARN)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local json = require("jsonlogs.json")

  -- Get all lines from buffer
  local all_lines = vim.api.nvim_buf_get_lines(ui_state.source_buf, 0, -1, false)
  local entries = {}

  for i, line in ipairs(all_lines) do
    if line ~= "" then
      local parsed = json.parse(line)
      local display = line

      if parsed then
        -- Create a better display string
        local timestamp = json.get_field(parsed, "timestamp") or ""
        local level = json.get_field(parsed, "level") or ""
        local message = json.get_field(parsed, "message") or ""

        if timestamp ~= "" or level ~= "" or message ~= "" then
          display = string.format("[%s] %s: %s", timestamp, level, message)
        end
      end

      table.insert(entries, {
        line_num = i,
        display = display,
        raw = line,
      })
    end
  end

  pickers
    .new({}, {
      prompt_title = "JSONL Log Entries",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return {
            value = entry,
            display = string.format("%4d: %s", entry.line_num, entry.display),
            ordinal = entry.display,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()

          if selection and ui_state.source_win then
            vim.api.nvim_win_set_cursor(ui_state.source_win, { selection.value.line_num, 0 })
          end
        end)
        return true
      end,
    })
    :find()
end

return M
