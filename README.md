# jsonlogs.nvim

A Neovim plugin for analyzing JSONL (JSON Lines) log files with a powerful split-panel interface.

## Features

- 📋 **Split Panel Interface**: Navigate logs in left panel, view pretty-printed JSON in right panel
- 🎨 **Syntax Highlighting**: JSON syntax highlighting in preview panel
- 🔍 **Smart Navigation**: Jump between error logs, search by field value, bookmark important entries
- 📊 **Analysis Tools**: Statistics, time-range filtering, field highlighting
- 🚀 **Advanced Features**: Live tail mode, jq integration, Telescope fuzzy search
- ⚙️ **Highly Configurable**: Customize all keybinds and behavior

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/jsonlogs.nvim",
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
  "yourusername/jsonlogs.nvim",
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

## Default Keybinds

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
| `d` | Diff with marked |
| `t` | Toggle tail mode |
| `s` | Show statistics |
| `q` | Close viewer |

## Commands

- `:JsonLogs [file]` - Open JSONL viewer (optional file path)
- `:JsonLogsGoto <line>` - Jump to specific line number
- `:JsonLogsClose` - Close the viewer
- `:JsonLogsStats` - Show log statistics (Phase 5)
- `:JsonLogsFilter --from <time> --to <time>` - Filter by time range (Phase 5)
- `:JsonLogsExport <file>` - Export filtered logs (Phase 5)
- `:JsonLogsTail` - Toggle live tail mode (Phase 6)
- `:JsonLogsJq '<filter>'` - Apply jq filter (Phase 6)

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
    -- ... see config.lua for full list
  },
})
```

## Implementation Status

- ✅ **Phase 1**: Core Foundation (split-panel viewer, JSON pretty-print)
- ✅ **Phase 2**: Syntax & Polish (highlighting, error handling)
- ✅ **Phase 3**: Navigation Features (error jumping, search, bookmarks)
- ✅ **Phase 4**: Display Features (folding, diff, compact mode)
- ✅ **Phase 5**: Analysis Features (statistics, filters, export)
- ✅ **Phase 6**: Advanced Features (tail, jq, Telescope, virtual text)

**Status**: All features implemented! Ready for testing and use.

## Requirements

- Neovim >= 0.8
- Optional: `jq` for handling very large JSON objects
- Optional: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for fuzzy search

## License

MIT

## Contributing

Contributions are welcome! Please open an issue or pull request.
