-- LRU cache for parsed JSON objects
-- This module provides caching to avoid re-parsing the same JSON lines repeatedly
-- when navigating through large JSONL files

local M = {}

-- Cache state
local cache_state = {
  parsed_cache = {},      -- { line_num = parsed_json }
  access_order = {},      -- Array of line_nums in access order (most recent at end)
  max_size = 100,         -- Maximum cached entries
  hits = 0,               -- Cache hits
  misses = 0,             -- Cache misses
}

-- Initialize or update cache configuration
-- @param config table: Configuration options (max_size)
function M.setup(config)
  config = config or {}
  if config.max_size then
    cache_state.max_size = config.max_size
  end
end

-- Get parsed JSON from cache or parse and cache it
-- @param line_num number: Line number (used as cache key)
-- @param line_content string: Raw JSON line content
-- @param parse_fn function: Function to parse JSON (receives line_content)
-- @return any|nil: Parsed JSON object or nil if parsing failed
function M.get_or_parse(line_num, line_content, parse_fn)
  -- Check cache first
  if cache_state.parsed_cache[line_num] then
    cache_state.hits = cache_state.hits + 1
    M._update_access_order(line_num)
    return cache_state.parsed_cache[line_num]
  end

  -- Cache miss - parse and cache
  cache_state.misses = cache_state.misses + 1

  local parsed = parse_fn(line_content)
  if parsed then
    M.cache(line_num, parsed)
  end

  return parsed
end

-- Cache a parsed JSON object
-- @param line_num number: Line number (used as cache key)
-- @param parsed table: Parsed JSON object
function M.cache(line_num, parsed)
  -- Evict oldest if cache is full
  if #cache_state.access_order >= cache_state.max_size then
    local oldest = cache_state.access_order[1]
    table.remove(cache_state.access_order, 1)
    cache_state.parsed_cache[oldest] = nil
  end

  -- Add to cache
  cache_state.parsed_cache[line_num] = parsed
  table.insert(cache_state.access_order, line_num)
end

-- Update access order for LRU (move to end = most recently used)
-- @param line_num number: Line number to mark as recently accessed
function M._update_access_order(line_num)
  -- Remove from current position
  for i, num in ipairs(cache_state.access_order) do
    if num == line_num then
      table.remove(cache_state.access_order, i)
      break
    end
  end

  -- Add to end (most recent)
  table.insert(cache_state.access_order, line_num)
end

-- Invalidate cache entries for a range of lines
-- @param start_line number: Start of range (inclusive)
-- @param end_line number: End of range (inclusive)
function M.invalidate_range(start_line, end_line)
  local to_remove = {}

  for i, line_num in ipairs(cache_state.access_order) do
    if line_num >= start_line and line_num <= end_line then
      table.insert(to_remove, line_num)
    end
  end

  for _, line_num in ipairs(to_remove) do
    cache_state.parsed_cache[line_num] = nil
    M._update_access_order(line_num)  -- Will be removed from order
  end

  -- Clean up access_order (removes nils we created)
  local new_order = {}
  for _, num in ipairs(cache_state.access_order) do
    if cache_state.parsed_cache[num] then
      table.insert(new_order, num)
    end
  end
  cache_state.access_order = new_order
end

-- Clear entire cache
function M.clear()
  cache_state.parsed_cache = {}
  cache_state.access_order = {}
  cache_state.hits = 0
  cache_state.misses = 0
end

-- Get cache statistics
-- @return table: { size, max_size, hits, misses, hit_rate }
function M.get_stats()
  local total_accesses = cache_state.hits + cache_state.misses
  local hit_rate = total_accesses > 0 and (cache_state.hits / total_accesses * 100) or 0

  return {
    size = #cache_state.access_order,
    max_size = cache_state.max_size,
    hits = cache_state.hits,
    misses = cache_state.misses,
    hit_rate = hit_rate,
  }
end

-- Check if a line is cached
-- @param line_num number: Line number to check
-- @return boolean: True if line is in cache
function M.is_cached(line_num)
  return cache_state.parsed_cache[line_num] ~= nil
end

-- Get cached value without updating access order
-- @param line_num number: Line number to get
-- @return any|nil: Cached value or nil if not in cache
function M.peek(line_num)
  return cache_state.parsed_cache[line_num]
end

-- Preload multiple lines into cache (useful for prefetching)
-- @param lines table: Array of {line_num, line_content} pairs
-- @param parse_fn function: Function to parse JSON
function M.preload(lines, parse_fn)
  for _, item in ipairs(lines) do
    local line_num, line_content = item[1], item[2]
    if not cache_state.parsed_cache[line_num] then
      local parsed = parse_fn(line_content)
      if parsed then
        M.cache(line_num, parsed)
      end
    end
  end
end

-- Resize cache (evicts excess entries if shrinking)
-- @param new_max_size number: New maximum cache size
function M.resize(new_max_size)
  local old_max = cache_state.max_size
  cache_state.max_size = new_max_size

  -- Evict excess if shrinking
  if new_max_size < old_max then
    while #cache_state.access_order > new_max_size do
      local oldest = cache_state.access_order[1]
      table.remove(cache_state.access_order, 1)
      cache_state.parsed_cache[oldest] = nil
    end
  end
end

return M
