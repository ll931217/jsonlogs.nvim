# Quick Start Guide - jsonlogs.nvim

## Installation

### Using lazy.nvim (Recommended)

Add to your Neovim configuration (`~/.config/nvim/lua/plugins/jsonlogs.lua`):

```lua
return {
  dir = vim.fn.getcwd(), -- For local development
  -- OR when published: "ll931217/jsonlogs.nvim",

  ft = "jsonl", -- Lazy load on .jsonl files

  opts = {
    auto_open = true, -- Automatically open viewer for .jsonl files
    prefix = "<leader>jl",
  },

  keys = {
    { "<leader>jl", "<cmd>JsonLogs<CR>", desc = "Open JSONL viewer" },
  },
}
```

### Manual Setup

Add to your `init.lua`:

```lua
vim.opt.rtp:append(vim.fn.getcwd()) -- Add current directory to runtime path

require("jsonlogs").setup({
  auto_open = true,
})
```

## First Use

1. **Open the sample file:**
   ```
   nvim sample.jsonl
   ```

2. **The viewer opens automatically** with:
   - Left panel: Raw JSONL logs
   - Right panel: Pretty-printed JSON

3. **Navigate:**
   - `j` / `k` - Move between log entries
   - `]e` / `[e` - Jump to errors
   - `/` - Search by field

4. **Explore features:**
   - `s` - Show statistics
   - `m` - Bookmark current line
   - `c` - Toggle compact mode
   - `d` - Mark for diff (press twice to see diff)
   - `t` - Toggle tail mode

5. **Close:**
   - `q` - Close viewer

## Key Features to Try

### 1. Error Navigation
```
Open sample.jsonl
Press ]e (jump to next error)
Notice it goes to line 4 (first error)
Press ]e again (line 6)
Press ]e again (line 8 - fatal)
```

### 2. Statistics Analysis
```
Open sample.jsonl
Press 's'
Review log level distribution
Press 'q' to close stats
```

### 3. Field Search
```
Press '/'
Enter field: service
Enter value: payment
Jumps to line 6 (payment error)
```

### 4. Diff View
```
Navigate to line 2
Press 'd' (marks for diff)
Navigate to line 4
Press 'd' again
New tab opens with side-by-side diff
```

### 5. Compact Mode
```
Press 'c'
Preview shows only: timestamp, level, message
Press 'c' again to restore full view
```

### 6. Live Tail (Advanced)
```
Open sample.jsonl
Press 't' (enables tail mode)

In another terminal:
  echo '{"timestamp":"2024-01-23T10:40:00Z","level":"info","message":"New!"}' >> sample.jsonl

Viewer auto-updates!
Press 't' to disable
```

## All Commands

| Command | Description |
|---------|-------------|
| `:JsonLogs` | Open viewer |
| `:JsonLogsStats` | Show statistics |
| `:JsonLogsFilter` | Filter by time range |
| `:JsonLogsFilterLevel` | Filter by level |
| `:JsonLogsExport` | Export to file |
| `:JsonLogsTail` | Toggle tail mode |
| `:JsonLogsJq` | Apply jq filter (requires jq) |
| `:JsonLogsTelescope` | Fuzzy search (requires telescope) |

## Tips

1. **Bookmarks for Important Logs**: Press `m` on critical errors, then `'` to see all bookmarks

2. **Quick Error Review**: Use `]e` to jump through all errors quickly

3. **Export Filtered Results**:
   ```
   :JsonLogsFilterLevel
   Select "error"
   :JsonLogsExport errors.jsonl
   ```

4. **Diff to Compare Requests**:
   - Mark first request with `d`
   - Navigate to second request
   - Press `d` to see differences

5. **Virtual Text Off**: Set `advanced.virtual_text = false` in config if annotations are distracting

## Troubleshooting

### Viewer doesn't open automatically
Check that `auto_open = true` in your config.

### jq filters don't work
Install jq: `brew install jq` (macOS) or `apt install jq` (Linux)

### Telescope picker not available
Install telescope.nvim: https://github.com/nvim-telescope/telescope.nvim

### Syntax highlighting missing
Ensure Neovim >= 0.8 and JSON TreeSitter parser installed: `:TSInstall json`

## Next Steps

- Read full documentation: `:help jsonlogs`
- Review all keybinds: `:help jsonlogs-keybinds`
- Customize configuration: `:help jsonlogs-configuration`
- Run full test suite: See `TESTING.md`

## Support

Report issues at: https://github.com/ll931217/jsonlogs.nvim/issues
