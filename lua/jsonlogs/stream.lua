-- Streaming engine for chunked file reading with line indexing
-- This module enables efficient handling of large JSONL files (100MB-1GB)
-- by maintaining a byte offset index for O(1) line access

local M = {}

-- State for indexed files
-- Format: { file_path = { line_positions = {}, total_lines = 0, mtime = 0 } }
local index_cache = {}

-- Build line position index by scanning the file
-- @param file_path string: Path to the file
-- @param progress_callback function: Called with (current_line, total_lines, percent) during scanning
-- @return table|nil: { line_positions = {}, total_lines = N } or nil on error
function M.build_index(file_path, progress_callback)
  -- Check if we can use cached index
  local stat = vim.loop.fs_stat(file_path)
  if not stat then
    vim.notify("Cannot stat file: " .. file_path, vim.log.levels.ERROR)
    return nil
  end

  local cached = index_cache[file_path]
  if cached and cached.mtime == stat.mtime.nsec then
    return cached
  end

  -- Open file in binary mode for efficient seeking
  local file, err = io.open(file_path, "rb")
  if not file then
    vim.notify("Failed to open file: " .. err, vim.log.levels.ERROR)
    return nil
  end

  local line_positions = { 0 }  -- Line 1 starts at byte 0
  local byte_offset = 0
  local line_count = 0
  local chunk_size = 8192  -- Read in 8KB chunks
  local last_progress_update = 0

  -- First pass: count total lines for progress tracking
  file:seek("set", 0)
  local total_lines = 0
  local line = file:read("*l")
  while line do
    total_lines = total_lines + 1
    -- Account for newline character(s)
    local current_pos = file:seek()
    if current_pos then
      local line_len = #line + 1  -- +1 for newline
      if line:find("\r\n") then
        line_len = line_len + 1  -- Windows CRLF
      end
      line = file:read("*l")
    else
      break
    end
  end

  -- Second pass: build index with progress tracking
  file:seek("set", 0)
  byte_offset = 0
  line_count = 0

  while true do
    local line = file:read("*l")
    if not line then
      break
    end

    line_count = line_count + 1
    local current_pos = file:seek()

    -- Store position of next line
    if current_pos then
      table.insert(line_positions, current_pos)
    else
      -- End of file
      table.insert(line_positions, byte_offset + #line + 1)
      break
    end

    -- Progress callback (call every 1000 lines or on completion)
    if progress_callback and (line_count % 1000 == 0 or line_count == total_lines) then
      local percent = math.floor((line_count / total_lines) * 100)
      progress_callback(line_count, total_lines, percent)
    end

    byte_offset = current_pos
  end

  file:close()

  -- Cache the index
  index_cache[file_path] = {
    line_positions = line_positions,
    total_lines = line_count,
    mtime = stat.mtime.nsec,
  }

  return index_cache[file_path]
end

-- Get a range of lines from the file
-- @param file_path string: Path to the file
-- @param start_line number: 1-indexed start line
-- @param end_line number: 1-indexed end line (inclusive)
-- @return table|nil: Array of lines or nil on error
function M.get_lines(file_path, start_line, end_line)
  local index_data = index_cache[file_path]
  if not index_data then
    index_data = M.build_index(file_path)
    if not index_data then
      return nil
    end
  end

  local line_positions = index_data.line_positions
  local total_lines = index_data.total_lines

  -- Clamp to valid range
  start_line = math.max(1, math.min(start_line, total_lines))
  end_line = math.max(start_line, math.min(end_line, total_lines))

  local file, err = io.open(file_path, "r")
  if not file then
    vim.notify("Failed to open file: " .. err, vim.log.levels.ERROR)
    return nil
  end

  local lines = {}

  -- Read lines using byte positions for efficient seeking
  for i = start_line, end_line do
    local pos = line_positions[i]
    if pos then
      file:seek("set", pos)
      local line = file:read("*l")
      if line then
        table.insert(lines, line)
      else
        table.insert(lines, "")  -- Empty line
      end
    end
  end

  file:close()
  return lines
end

-- Get a single line from the file
-- @param file_path string: Path to the file
-- @param line_num number: 1-indexed line number
-- @return string|nil: Line content or nil on error
function M.get_line(file_path, line_num)
  local lines = M.get_lines(file_path, line_num, line_num)
  if lines and #lines > 0 then
    return lines[1]
  end
  return nil
end

-- Get total line count from index
-- @param file_path string: Path to the file
-- @return number: Total line count
function M.get_total_lines(file_path)
  local index_data = index_cache[file_path]
  if not index_data then
    index_data = M.build_index(file_path)
    if not index_data then
      return 0
    end
  end
  return index_data.total_lines
end

-- Lazy iterator for streaming operations
-- @param file_path string: Path to the file
-- @param start_line number: 1-indexed start line
-- @param end_line number: 1-indexed end line (inclusive, or nil for EOF)
-- @return function: Iterator that yields (line_num, line) on each call
function M.iter_lines(file_path, start_line, end_line)
  local index_data = index_cache[file_path]
  if not index_data then
    index_data = M.build_index(file_path)
    if not index_data then
      return function() return nil end
    end
  end

  if not end_line then
    end_line = index_data.total_lines
  end

  start_line = math.max(1, start_line)
  end_line = math.min(end_line, index_data.total_lines)

  local current_line = start_line - 1
  local file = io.open(file_path, "r")

  if not file then
    return function() return nil end
  end

  -- Return iterator function
  return function()
    current_line = current_line + 1

    if current_line > end_line then
      file:close()
      return nil
    end

    local pos = index_data.line_positions[current_line]
    if pos then
      file:seek("set", pos)
      local line = file:read("*l")
      return current_line, line or ""
    end

    file:close()
    return nil
  end
end

-- Update index incrementally for new lines (e.g., in tail mode)
-- @param file_path string: Path to the file
-- @param index_data table: Existing index data to update
-- @return table|nil: Updated index data or nil on error
function M.update_index(file_path, index_data)
  local stat = vim.loop.fs_stat(file_path)
  if not stat then
    return nil
  end

  local file, err = io.open(file_path, "rb")
  if not file then
    vim.notify("Failed to open file: " .. err, vim.log.levels.ERROR)
    return nil
  end

  local line_positions = index_data.line_positions
  local last_known_pos = line_positions[#line_positions]

  -- Seek to last known position
  file:seek("set", last_known_pos)
  local current_pos = last_known_pos
  local line_count = index_data.total_lines

  -- Read new lines
  while true do
    local line = file:read("*l")
    if not line then
      break
    end

    line_count = line_count + 1
    current_pos = file:seek()

    if current_pos then
      table.insert(line_positions, current_pos)
    else
      -- End of file
      table.insert(line_positions, last_known_pos + #line + 1)
      break
    end

    last_known_pos = current_pos
  end

  file:close()

  -- Update cache
  index_cache[file_path] = {
    line_positions = line_positions,
    total_lines = line_count,
    mtime = stat.mtime.nsec,
  }

  return index_cache[file_path]
end

-- Clear cached index for a file
-- @param file_path string: Path to the file (or nil to clear all)
function M.clear_cache(file_path)
  if file_path then
    index_cache[file_path] = nil
  else
    index_cache = {}
  end
end

-- Get cached index data without rebuilding
-- @param file_path string: Path to the file
-- @return table|nil: Cached index data or nil if not cached
function M.get_cached_index(file_path)
  return index_cache[file_path]
end

-- Check if file has been modified since indexing
-- @param file_path string: Path to the file
-- @return boolean: True if file has been modified
function M.is_modified(file_path)
  local cached = index_cache[file_path]
  if not cached then
    return true  -- Not indexed yet
  end

  local stat = vim.loop.fs_stat(file_path)
  if not stat then
    return true  -- File doesn't exist
  end

  return cached.mtime ~= stat.mtime.nsec
end

-- Get file size in MB
-- @param file_path string: Path to the file
-- @return number: File size in MB
function M.get_file_size_mb(file_path)
  local stat = vim.loop.fs_stat(file_path)
  if stat and stat.size then
    return stat.size / (1024 * 1024)
  end
  return 0
end

return M
