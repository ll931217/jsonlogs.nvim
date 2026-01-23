# Testing Checklist for jsonlogs.nvim

## Prerequisites

1. Neovim >= 0.8 installed
2. Optional: `jq` installed for jq integration
3. Optional: `telescope.nvim` installed for Telescope integration
4. Sample JSONL file (`sample.jsonl` provided in repository)

## Phase 1: Core Foundation

### Basic Viewer
- [ ] Open `sample.jsonl` file in Neovim
- [ ] Verify split panel opens automatically (left: raw logs, right: preview)
- [ ] Navigate with `j`/`k` and verify right panel updates
- [ ] Check that JSON is pretty-printed with proper indentation
- [ ] Verify line 10 (malformed JSON) shows error message gracefully
- [ ] Press `q` to close, verify both panels close

### Manual Commands
- [ ] Run `:JsonLogs sample.jsonl` - viewer should open
- [ ] Run `:JsonLogsGoto 5` - should jump to line 5
- [ ] Run `:JsonLogsClose` - viewer should close

## Phase 2: Syntax & Polish

### Syntax Highlighting
- [ ] Open viewer and verify JSON syntax highlighting in preview panel
- [ ] Check that different log levels have different colors in source panel:
  - Line 1 (info) - blue-ish
  - Line 3 (warn) - orange-ish
  - Line 4, 6 (error) - red background
  - Line 8 (fatal) - bright red background

### Error Handling
- [ ] Navigate to line 10 (malformed JSON)
- [ ] Verify preview shows clear error message
- [ ] Verify raw line is displayed for debugging

### Status Line
- [ ] Check status line shows "Line X/11" format
- [ ] Toggle compact mode (`c`), verify status shows "[COMPACT]"

## Phase 3: Navigation Features

### Error Jumping
- [ ] Start at line 1
- [ ] Press `]e` to jump to next error (should go to line 4)
- [ ] Press `]e` again (should go to line 6)
- [ ] Press `]e` again (should go to line 8)
- [ ] Press `[e` to go back to line 6
- [ ] Verify wrap-around behavior

### Field Search
- [ ] Press `/` to search
- [ ] Enter field: `service`
- [ ] Enter value: `payment`
- [ ] Should jump to line 6
- [ ] Search again, verify it finds matches

### Bookmarks
- [ ] Navigate to line 4
- [ ] Press `m` to bookmark (should show bookmark indicator)
- [ ] Navigate to line 6, press `m`
- [ ] Navigate to line 8, press `m`
- [ ] Press `'` to list bookmarks
- [ ] Select one from the list, verify jump works
- [ ] Press `m` on bookmarked line to remove bookmark

## Phase 4: Display Features

### Folding
- [ ] Navigate to a line with nested JSON (e.g., line 2)
- [ ] In preview panel, press `<CR>` to toggle fold
- [ ] Verify nested "details" object folds/unfolds
- [ ] Check fold text shows structure summary

### Diff View
- [ ] Navigate to line 2 (info log)
- [ ] Press `d` to mark for diff
- [ ] Navigate to line 4 (error log)
- [ ] Press `d` again
- [ ] Verify new tab opens with side-by-side diff
- [ ] Check diff highlights differences
- [ ] Close diff tab

### Compact Mode
- [ ] Press `c` to toggle compact mode
- [ ] Verify preview shows only: timestamp, level, message
- [ ] Press `c` again to return to full view

## Phase 5: Analysis Features

### Statistics
- [ ] Press `s` (or run `:JsonLogsStats`)
- [ ] Verify floating window shows:
  - Total entries: 10 (excluding malformed line)
  - Parse errors: 1
  - Log level breakdown (info, warn, error, fatal, debug)
  - Service distribution
  - Common fields
- [ ] Press `q` to close stats window

### Time Range Filter
- [ ] Run `:JsonLogsFilter`
- [ ] From: `2024-01-23T10:31:00Z`
- [ ] To: `2024-01-23T10:35:00Z`
- [ ] Verify new tab with filtered results (should show 5 entries)
- [ ] Close filtered tab

### Level Filter
- [ ] Run `:JsonLogsFilterLevel`
- [ ] Select "error"
- [ ] Verify new tab shows only error-level logs (3 entries: lines 4, 6, 8)
- [ ] Close filtered tab

### Export
- [ ] Run `:JsonLogsExport test_export.jsonl`
- [ ] Verify file is created
- [ ] Check file contains all log entries
- [ ] Delete test file: `rm test_export.jsonl`

### Yank JSON
- [ ] Navigate to line 2
- [ ] Press `y` to yank
- [ ] Paste into another buffer (`:new` then `p`)
- [ ] Verify pretty-printed JSON is pasted
- [ ] Close scratch buffer

## Phase 6: Advanced Features

### Live Tail Mode
- [ ] Open viewer on `sample.jsonl`
- [ ] Press `t` to enable tail mode
- [ ] In another terminal: `echo '{"timestamp":"2024-01-23T10:38:00Z","level":"info","message":"New entry"}' >> sample.jsonl`
- [ ] Verify viewer auto-updates and jumps to new line
- [ ] Press `t` to disable tail mode
- [ ] Clean up: `git checkout sample.jsonl` (restore original)

### jq Integration (if jq installed)
- [ ] Press `J` (or run `:JsonLogsJq`)
- [ ] Enter filter: `.user_id`
- [ ] Verify new tab shows user_id values from each log
- [ ] Close tab
- [ ] Try filter: `select(.level=="error")`
- [ ] Verify only error entries shown

### Telescope Integration (if installed)
- [ ] Press `<C-f>` (or run `:JsonLogsTelescope`)
- [ ] Verify Telescope picker opens with all log entries
- [ ] Type to fuzzy search (e.g., "payment")
- [ ] Press `<CR>` to select
- [ ] Verify cursor jumps to selected line
- [ ] Close Telescope

### Virtual Text Annotations
- [ ] Check that logs show inline annotations:
  - Relative timestamps ("2h ago", "1d ago")
  - Duration indicators (line 7: "⏱ 5.0s")
  - Error messages (line 4, 6: "⚠ ECONNREFUSED", etc.)
- [ ] Verify annotations don't interfere with editing

## Stress Testing

### Large Files
- [ ] Generate large JSONL file: `for i in {1..1000}; do cat sample.jsonl; done > large.jsonl`
- [ ] Open in viewer: `:JsonLogs large.jsonl`
- [ ] Navigate to end (`G`), verify performance
- [ ] Run statistics, verify completes in reasonable time
- [ ] Clean up: `rm large.jsonl`

### Edge Cases
- [ ] Empty JSONL file
- [ ] File with only malformed JSON
- [ ] Very long JSON lines (>10KB)
- [ ] Deeply nested JSON objects

## Integration Testing

### With lazy.nvim
- [ ] Configure plugin in lazy.nvim config
- [ ] Verify lazy loading on `.jsonl` files works
- [ ] Check keybinds are properly registered

### Configuration Override
- [ ] Set custom keybinds in setup()
- [ ] Verify custom keybinds work
- [ ] Change layout position to "bottom"
- [ ] Verify horizontal split

## Regression Testing

### After Updates
- [ ] Re-run all tests above
- [ ] Check for Lua errors in `:messages`
- [ ] Verify no memory leaks (long-running session)

## Sign-off

- [ ] All Phase 1 tests passing
- [ ] All Phase 2 tests passing
- [ ] All Phase 3 tests passing
- [ ] All Phase 4 tests passing
- [ ] All Phase 5 tests passing
- [ ] All Phase 6 tests passing
- [ ] No Lua errors in `:messages`
- [ ] Performance acceptable on 1000+ line files

**Testing completed by:** ________________
**Date:** ________________
**Neovim version:** ________________
**Notes:** ________________
