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
  -- Keybind prefix
  prefix = "<leader>jl",

  -- Auto-open for .jsonl files
  auto_open = true,

  -- Panel layout
  layout = {
    position = "right",  -- "right" or "bottom"
    width = 80,
    height = 20,
  },

  -- JSON settings
  json = {
    indent = 2,
    use_jq_fallback = true,  -- Use jq for large objects if available
    jq_path = "jq",
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
    compact_fields = { "timestamp", "level", "message" },  -- Fields for compact mode
    table_max_col_width = 30,      -- Max column width in table mode
    table_null_placeholder = "-",  -- Placeholder for missing values in table mode
    table_page_size = 50,          -- Entries per page in table mode (pagination)
  },

  -- Analysis settings
  analysis = {
    timestamp_field = "timestamp",  -- Field containing timestamp
    timestamp_formats = {           -- Supported timestamp formats
      "%Y-%m-%dT%H:%M:%S",
      "%Y-%m-%d %H:%M:%S",
      "iso8601",
    },
  },

  -- Performance settings
  performance = {
    use_jq_for_tables = true,  -- Use jq for table formatting (faster for large files)
  },

  -- Advanced settings
  advanced = {
    tail_update_interval = 100,  -- Milliseconds between tail updates
    max_preview_size = 10000,    -- Max chars for pretty-print (fallback to jq)
    virtual_text = true,         -- Enable virtual text annotations
  },

  -- Streaming settings for large files (100MB-1GB)
  streaming = {
    enabled = "auto",              -- true, false, or "auto" (auto enables for files > threshold_mb)
    threshold_mb = 10,             -- File size threshold in MB for auto-enabling streaming
    chunk_size = 1000,             -- Number of lines to load at once
    cache_size = 100,              -- Maximum parsed JSON objects to cache
    table_sample_size = 1000,      -- Sample size for discovering table columns
    stats_sample_size = 10000,     -- Sample size for statistics calculation
    show_progress = true,           -- Show progress for long operations
  },

  -- Keybinds (all available keys for customization)
  keys = {
    quit = "q",                  -- Close viewer
    next_entry = "j",            -- Next log entry
    prev_entry = "k",            -- Previous log entry
    next_error = "]e",           -- Next error
    prev_error = "[e",           -- Previous error
    first_entry = "gg",          -- First entry
    last_entry = "G",            -- Last entry
    toggle_fold = "<CR>",        -- Toggle fold
    yank_json = "y",             -- Yank formatted JSON
    bookmark = "m",              -- Bookmark line
    list_bookmarks = "'",        -- List bookmarks
    search = "/",                -- Search by field
    compact_mode = "c",          -- Toggle compact mode
    diff_view = "d",             -- Diff with marked
    tail_mode = "t",             -- Toggle tail mode
    stats = "s",                 -- Show statistics
    table_mode = "T",            -- Toggle table preview mode
    table_columns = "C",          -- Open column filter modal
    table_next_page = "]",        -- Next page in table mode
    table_prev_page = "[",        -- Previous page in table mode
    table_first_page = "[[",      -- First page in table mode
    table_last_page = "]]",       -- Last page in table mode
    inspect_cell = "<CR>",        -- Inspect table cell (in table mode)
    switch_pane = "<Tab>",        -- Toggle between source and preview panes
    maximize_preview = "f",       -- Toggle preview panel maximize/restore
  },
})
```

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
