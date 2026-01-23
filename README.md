# jsonlogs.nvim

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.8+-green.svg)](https://neovim.io)

A powerful Neovim plugin for analyzing JSONL (JSON Lines) log files with an intuitive split-panel interface.

## ✨ Features

- 📋 **Split Panel Interface**: Navigate logs in left panel, view pretty-printed JSON in right panel
- 🎨 **Syntax Highlighting**: JSON syntax highlighting with custom color schemes
- 🔍 **Smart Navigation**: Jump between error logs, search by field value, bookmark important entries
- 📊 **Table Preview Mode**: View all log entries as a markdown table with flattened columns and interactive column filtering
- 📈 **Analysis Tools**: Statistics, time-range filtering, field highlighting
- 🚀 **Advanced Features**: Live tail mode, jq integration, Telescope fuzzy search
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
5. Press `q` to close

## ⌨️ Default Keybinds

| Key | Action |
|-----|--------|
| `j` / `k` | Next/previous log entry |
| `gg` / `G` | First/last entry |
| `]e` / `[e` | Next/previous error |
| `<CR>` | Toggle fold |
| `y` | Yank formatted JSON |
| `m` | Bookmark line |
| `'` | List bookmarks |
| `/` | Search by field |
| `c` | Toggle compact mode |
| `T` | Toggle table preview mode |
| `C` | Open column filter (in table mode) |
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
    use_jq_fallback = true,
    jq_path = "jq",
  },

  -- Navigation
  navigation = {
    error_field = "level",
    error_values = { "error", "ERROR", "fatal", "FATAL" },
  },

  -- Display
  display = {
    show_line_numbers = true,
    syntax_highlighting = true,
    compact_fields = { "timestamp", "level", "message" },
    table_max_col_width = 30,      -- Max column width in table mode
    table_null_placeholder = "-",  -- Placeholder for missing values
  },

  -- Analysis
  analysis = {
    timestamp_field = "timestamp",
    timestamp_formats = {
      "%Y-%m-%dT%H:%M:%S",
      "%Y-%m-%d %H:%M:%S",
      "iso8601",
    },
  },

  -- Advanced
  advanced = {
    tail_update_interval = 100,
    max_preview_size = 10000,
    virtual_text = true,
  },

  -- Keybinds (customize any/all)
  keys = {
    quit = "q",
    next_entry = "j",
    prev_entry = "k",
    next_error = "]e",
    prev_error = "[e",
    compact_mode = "c",
    table_mode = "T",      -- Toggle table preview
    table_columns = "C",   -- Column filter
    tail_mode = "t",
    stats = "s",
    -- ... see config.lua for full list
  },
})
```

## 📊 Table Preview Mode

Press `T` to view all log entries as a spreadsheet-like markdown table:

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
- Shows all entries in one view (spreadsheet mode)

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
