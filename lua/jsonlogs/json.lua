-- JSON parsing and pretty-printing module
local M = {}

-- Parse a JSON line
-- @param line string: The JSON line to parse
-- @return table|nil: Parsed JSON object or nil if parse fails
-- @return string|nil: Error message if parse fails
function M.parse(line)
  if not line or line == "" then
    return nil, "Empty line"
  end

  local ok, result = pcall(vim.json.decode, line)
  if ok then
    return result, nil
  else
    return nil, "Invalid JSON: " .. tostring(result)
  end
end

-- Pretty-print JSON using pure Lua
-- @param obj table: The JSON object to format
-- @param indent number: Current indentation level
-- @return table: Array of formatted lines
local function pretty_print_lua(obj, indent)
  indent = indent or 0
  local lines = {}
  local indent_str = string.rep(" ", indent)

  if type(obj) ~= "table" then
    return { tostring(obj) }
  end

  -- Check if it's an array
  local is_array = vim.tbl_islist(obj)

  if is_array then
    table.insert(lines, "[")
    for i, value in ipairs(obj) do
      local value_lines = pretty_print_lua(value, indent + 2)
      local prefix = string.rep(" ", indent + 2)

      if #value_lines == 1 then
        local suffix = i < #obj and "," or ""
        table.insert(lines, prefix .. value_lines[1] .. suffix)
      else
        for j, line in ipairs(value_lines) do
          if j == 1 then
            table.insert(lines, prefix .. line)
          elseif j == #value_lines then
            local suffix = i < #obj and "," or ""
            table.insert(lines, line .. suffix)
          else
            table.insert(lines, line)
          end
        end
      end
    end
    table.insert(lines, indent_str .. "]")
  else
    table.insert(lines, "{")
    local keys = vim.tbl_keys(obj)
    table.sort(keys)

    for i, key in ipairs(keys) do
      local value = obj[key]
      local value_lines = pretty_print_lua(value, indent + 2)
      local prefix = string.rep(" ", indent + 2)
      local key_str = string.format('"%s": ', key)

      if #value_lines == 1 then
        local suffix = i < #keys and "," or ""
        table.insert(lines, prefix .. key_str .. value_lines[1] .. suffix)
      else
        table.insert(lines, prefix .. key_str .. value_lines[1])
        for j = 2, #value_lines - 1 do
          table.insert(lines, value_lines[j])
        end
        local suffix = i < #keys and "," or ""
        table.insert(lines, value_lines[#value_lines] .. suffix)
      end
    end
    table.insert(lines, indent_str .. "}")
  end

  return lines
end

-- Pretty-print JSON using jq (fallback for large objects)
-- @param json_str string: The raw JSON string
-- @param jq_path string: Path to jq binary
-- @return table|nil: Array of formatted lines or nil if jq fails
local function pretty_print_jq(json_str, jq_path)
  local temp_file = vim.fn.tempname()
  local output_file = vim.fn.tempname()

  -- Write JSON to temp file
  local f = io.open(temp_file, "w")
  if not f then
    return nil
  end
  f:write(json_str)
  f:close()

  -- Run jq
  local cmd = string.format('%s . %s > %s 2>/dev/null', jq_path, temp_file, output_file)
  local exit_code = os.execute(cmd)

  -- Clean up temp file
  os.remove(temp_file)

  if exit_code ~= 0 then
    os.remove(output_file)
    return nil
  end

  -- Read output
  local lines = {}
  f = io.open(output_file, "r")
  if f then
    for line in f:lines() do
      table.insert(lines, line)
    end
    f:close()
  end

  os.remove(output_file)
  return #lines > 0 and lines or nil
end

-- Pretty-print a JSON object
-- @param obj table|string: The JSON object or string to format
-- @param config table: Configuration options
-- @return table: Array of formatted lines
-- @return string|nil: Error message if formatting fails
function M.pretty_print(obj, config)
  config = config or {}
  local use_jq = config.use_jq_fallback
  local jq_path = config.jq_path or "jq"
  local max_size = config.max_preview_size or 10000

  -- If obj is a string, parse it first
  local parsed_obj = obj
  if type(obj) == "string" then
    local err
    parsed_obj, err = M.parse(obj)
    if not parsed_obj then
      return { "Error: " .. err }, err
    end
  end

  -- Try jq fallback for large objects
  if use_jq then
    local json_str = vim.json.encode(parsed_obj)
    if #json_str > max_size then
      local jq_lines = pretty_print_jq(json_str, jq_path)
      if jq_lines then
        return jq_lines, nil
      end
    end
  end

  -- Use pure Lua pretty-print
  local lines = pretty_print_lua(parsed_obj, 0)
  return lines, nil
end

-- Get a specific field value from a JSON object
-- @param obj table: The JSON object
-- @param field_path string: Dot-separated field path (e.g., "user.id")
-- @return any: The field value or nil if not found
function M.get_field(obj, field_path)
  if type(obj) ~= "table" then
    return nil
  end

  local parts = vim.split(field_path, ".", { plain = true })
  local current = obj

  for _, part in ipairs(parts) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[part]
    if current == nil then
      return nil
    end
  end

  return current
end

-- Check if a JSON object matches a field filter
-- @param obj table: The JSON object
-- @param field string: Field name
-- @param value any: Expected value
-- @return boolean: True if matches
function M.matches_filter(obj, field, value)
  local field_value = M.get_field(obj, field)
  if field_value == nil then
    return false
  end

  -- Case-insensitive string comparison
  if type(field_value) == "string" and type(value) == "string" then
    return string.lower(field_value) == string.lower(value)
  end

  return field_value == value
end

return M
