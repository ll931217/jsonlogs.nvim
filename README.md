# jsonlogs.nvim

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.8+-green.svg)](https://neovim.io)

A powerful Neovim plugin for analyzing JSONL (JSON Lines) log files with an intuitive split-panel interface.

## ✨ Features

- 📋 **Split Panel Interface**: Navigate logs in left panel, view pretty-printed JSON in right panel
- 🎨 **Syntax Highlighting**: JSON syntax highlighting with custom color schemes
- 🔍 **Smart Navigation**: Jump between error logs, search by field value, bookmark important entries
- 🔄 **Pane Switching**: Quick toggle between panes with `<Tab>`
- 📊 **Table Preview Mode**: View log entries as a paginated markdown table with flattened columns and interactive column filtering
- 📄 **Pagination**: Efficient table mode with configurable page size (50 entries per page)
- 🔎 **Cell Inspection**: Press Enter on any table cell to view full content (with truncation indicators ▶)
- 🔬 **Column Zoom**: Zoom into any column to see all its values (press 'z' in cell inspection)
- 📐 **Resizable Preview**: Toggle preview panel to full width with `f`
- 📈 **Analysis Tools**: Statistics, time-range filtering, field highlighting
- 🚀 **Advanced Features**: Live tail mode, jq integration, Telescope fuzzy search
- 📦 **Large File Support**: Streaming mode for files 100MB-1GB with chunk loading
- ⚙️ **Highly Configurable**: Customize all keybinds and behavior

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ll931217/jsonlogs.nvim",
  ft = "jsonl",  -- Lazy load on .jsonl files
  opts = {
    -- Custom configuration (optional)
    prefix = "<leader>jl",
    auto_open = true,
  },
  keys = {
    { "<leader>jl", "<cmd>JsonLogs<CR>", desc = "Open JSONL viewer" },
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "ll931217/jsonlogs.nvim",
  config = function()
    require("jsonlogs").setup({
      prefix = "<leader>jl",
      auto_open = true,
    })
  end,
}
```

## Quick Start

1. Open any `.jsonl` file in Neovim
2. The split-panel viewer will automatically open
3. Navigate through logs with `j`/`k`
4. View pretty-printed JSON in the right panel
5. Press `<Tab>` to toggle between panes
6. Press `q` to close

## ⌨️ Default Keybinds

| Key | Action |
|-----|--------|
| `j` / `k` | Next/previous log entry |
| `gg` / `G` | First/last entry |
| `]e` / `[e` | Next/previous error |
| `<Tab>` | Toggle between source and preview panes |
| `<CR>` | Toggle fold / Inspect table cell (in table mode) |
| `y` | Yank formatted JSON |
| `m` | Bookmark line |
| `'` | List bookmarks |
| `/` | Search by field |
| `c` | Toggle compact mode |
| `T` | Toggle table preview mode |
| `C` | Open column filter (in table mode) |
| `]` / `[` | Next/previous page (table mode) |
| `]]` / `[[` | Last/first page (table mode) |
| `f` | Toggle preview maximize/restore |
| `d` | Diff with marked |
| `t` | Toggle tail mode |
| `s` | Show statistics |
| `q` | Close viewer |

## 📋 Commands

- `:JsonLogs [file]` - Open JSONL viewer (optional file path)
- `:JsonLogsGoto <line>` - Jump to specific line number
- `:JsonLogsClose` - Close the viewer
- `:JsonLogsStats` - Show log statistics
- `:JsonLogsFilter --from <time> --to <time>` - Filter by time range
- `:JsonLogsExport <file>` - Export filtered logs
- `:JsonLogsTail` - Toggle live tail mode
- `:JsonLogsTableColumns` - Open column filter modal (table mode)
- `:JsonLogsJq '<filter>'` - Apply jq filter

## Configuration

```lua
require("jsonlogs").setup({
  -- =============================================
  -- Basic Options
  -- =============================================

  -- Keybind prefix (used for some commands)
  prefix = "<leader>jl",

  -- Automatically open viewer when opening .jsonl files
  auto_open = true,

  -- =============================================
  -- Panel Layout
  -- =============================================

  layout = {
    -- Preview panel position: "right" (vertical) or "bottom" (horizontal)
    position = "right",
    -- Preview panel width (for vertical split)
    width = 80,
    -- Preview panel height (for horizontal split)
    height = 20,
  },

  -- =============================================
  -- JSON Formatting
  -- =============================================

  json = {
    -- Indentation spaces for pretty-printed JSON
    indent = 2,
    -- Use jq CLI tool for formatting very large JSON objects (>10KB)
    use_jq_fallback = true,
    -- Path to jq binary (if not in PATH)
    jq_path = "jq",
  },

  -- =============================================
  -- Navigation
  -- =============================================

  navigation = {
    -- Field name to check for error detection (e.g., "level", "severity")
    error_field = "level",
    -- Values that indicate an error
    error_values = { "error", "ERROR", "fatal", "FATAL" },
  },

  -- =============================================
  -- Display
  -- =============================================

  display = {
    -- Show line numbers in preview buffer
    show_line_numbers = true,
    -- Enable JSON syntax highlighting
    syntax_highlighting = true,
    -- Fields to show in compact mode
    compact_fields = { "timestamp", "level", "message" },
    -- Maximum column width in table mode (cells are truncated with "..." if longer)
    table_max_col_width = 30,
    -- Placeholder text for null/missing values in table mode
    table_null_placeholder = "-",
    -- Number of entries per page in table mode (pagination)
    table_page_size = 50,
  },

  -- =============================================
  -- Analysis
  -- =============================================

  analysis = {
    -- Field name containing timestamps for time-range filtering
    timestamp_field = "timestamp",
    -- Supported timestamp formats for parsing
    timestamp_formats = {
      "%Y-%m-%dT%H:%M:%S",  -- ISO 8601 without timezone
      "%Y-%m-%d %H:%M:%S",  -- Common database format
      "iso8601",             -- Full ISO 8601 with timezone
    },
  },

  -- =============================================
  -- Performance
  -- =============================================

  performance = {
    -- Use jq for table formatting (faster for large files)
    -- Falls back to pure Lua if jq is not available
    use_jq_for_tables = true,
  },

  -- =============================================
  -- Advanced
  -- =============================================

  advanced = {
    -- Update interval for tail mode in milliseconds
    tail_update_interval = 100,
    -- Maximum character count for JSON pretty-print before using jq fallback
    max_preview_size = 10000,
    -- Show virtual text annotations (e.g., line info)
    virtual_text = true,
  },

  -- =============================================
  -- Streaming Mode (Large Files: 100MB-1GB)
  -- =============================================

  streaming = {
    -- Enable streaming: true, false, or "auto"
    -- "auto" enables streaming for files larger than threshold_mb
    enabled = "auto",
    -- File size threshold in MB for auto-enabling streaming
    threshold_mb = 10,
    -- Number of lines to load per chunk
    chunk_size = 1000,
    -- Maximum parsed JSON objects to keep in memory
    cache_size = 100,
    -- Sample size for discovering table columns (to avoid loading entire file)
    table_sample_size = 1000,
    -- Sample size for statistics calculation
    stats_sample_size = 10000,
    -- Show progress messages for long operations
    show_progress = true,
  },

  -- =============================================
  -- Keybindings
  -- =============================================

  keys = {
    -- Navigation
    quit = "q",                  -- Close viewer
    next_entry = "j",            -- Next log entry
    prev_entry = "k",            -- Previous log entry
    first_entry = "gg",          -- First entry
    last_entry = "G",            -- Last entry

    -- Error Navigation
    next_error = "]e",           -- Next error log
    prev_error = "[e",           -- Previous error log

    -- Preview Actions
    toggle_fold = "<CR>",        -- Toggle fold in preview
    yank_json = "y",             -- Yank formatted JSON to clipboard
    switch_pane = "<Tab>",       -- Toggle between source and preview panes
    maximize_preview = "f",      -- Toggle preview panel maximize/restore

    -- Search & Filter
    search = "/",                -- Search by field value

    -- Bookmarks
    bookmark = "m",              -- Bookmark current line
    list_bookmarks = "'",        -- List all bookmarks

    -- Display Modes
    compact_mode = "c",          -- Toggle compact view
    table_mode = "T",            -- Toggle table preview mode

    -- Table Mode Pagination
    table_next_page = "]",       -- Next page
    table_prev_page = "[",       -- Previous page
    table_first_page = "[[",     -- First page
    table_last_page = "]]",      -- Last page

    -- Table Mode Features
    table_columns = "C",         -- Open column filter modal
    inspect_cell = "<CR>",       -- Inspect table cell (press in preview)

    -- Analysis
    diff_view = "d",             -- Diff with marked line
    tail_mode = "t",             -- Toggle live tail mode
    stats = "s",                 -- Show log statistics
  },
})
```

### Configuration Notes

- **Streaming Mode**: Automatically enabled for files >10MB. Loads data in chunks to avoid memory issues.
- **jq Integration**: Requires `jq` to be installed. Falls back gracefully if unavailable.
- **Table Mode**: Paginated view shows 50 entries per page by default. Use `]`/`[` to navigate pages.
- **Custom Keybindings**: Override any key by setting it in the `keys` table.

## 📊 Table Preview Mode

Press `T` to view log entries as a spreadsheet-like markdown table:

```markdown
| id | level | message            | user.name | user.age | tags[0] | tags[1] | service  |
|----|-------|--------------------|-----------|----------|---------|---------|----------|
| 1  | info  | User logged in     | Alice     | 30       | vim     | lua     | auth     |
| 2  | warn  | Slow query detected| Bob       | 25       | rust    | -       | database |
| 3  | error | Connection timeout | Carol     | 35       | python  | js      | api      |
```

**Features:**
- Flattens nested objects (`user.name`, `user.age`)
- Array indexing (`tags[0]`, `tags[1]`)
- Interactive column filtering with `C`
- Configurable column widths and null placeholders
- **Pagination** for large files (50 entries per page by default)
- Navigate pages with `]` (next), `[` (previous), `]]` (last), `[[` (first)
- **Cell Inspection**: Press Enter on any cell to view full content (truncated cells show ▶ indicator)
- **Column Zoom**: Press `z` in cell inspection to see all values from that column
- **Maximize Preview**: Press `f` to expand preview to full width

**Navigation:**
- Press `<Tab>` to toggle between source and preview panes
- Press `Enter` on any cell to inspect its full content
- Use `]`/`[` to navigate pages in table mode
- Each page shows "Page X of Y (showing entries X-Y of Z)"

## 🚀 Implementation Status

- ✅ **Phase 1**: Core Foundation (split-panel viewer, JSON pretty-print)
- ✅ **Phase 2**: Syntax & Polish (highlighting, error handling)
- ✅ **Phase 3**: Navigation Features (error jumping, search, bookmarks)
- ✅ **Phase 4**: Display Features (folding, diff, compact mode)
- ✅ **Phase 5**: Analysis Features (statistics, filters, export)
- ✅ **Phase 6**: Advanced Features (tail, jq, Telescope, virtual text)
- ✅ **Phase 7**: Table Preview Mode (spreadsheet view, column filtering)

**Status**: All features implemented! Ready for production use. 🎉

## 📦 Requirements

- Neovim >= 0.8
- Optional: `jq` for handling very large JSON objects
- Optional: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for fuzzy search

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

- 🐛 Report bugs by opening an [issue](https://github.com/ll931217/jsonlogs/issues)
- 💡 Suggest new features or improvements
- 🔧 Submit pull requests with bug fixes or new features
- 📖 Improve documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Built with ❤️ for the Neovim community.
