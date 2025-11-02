-- Input field management for wherewolf.nvim

local state = require("wherewolf.ui.state")
local highlights = require("wherewolf.ui.highlights")

local M = {}

---Get the namespace for extmarks
---@return number
local function get_ns()
  return highlights.get_namespace()
end

---Extract input value from buffer line
---@param buf number Buffer handle
---@param line_num number Line number (0-indexed)
---@param prefix string Prefix to remove (e.g., "  Pattern: ")
---@return string value Input value
local function get_line_value(buf, line_num, prefix)
  local lines = vim.api.nvim_buf_get_lines(buf, line_num, line_num + 1, false)
  if #lines == 0 then
    return ""
  end

  local line = lines[1]
  -- Remove prefix
  local value = line:sub(#prefix + 1)
  return value
end

---Update input value in state from buffer
---@param buf number Buffer handle
---@param field_name string Field name (search, replace, include, exclude)
local function sync_input_from_buffer(buf, field_name)
  local line_num = state.input_lines[field_name]
  if not line_num then
    return
  end

  local prefixes = {
    search = "  Pattern: ",
    replace = "  Replace: ",
    include = "  Files:   ",
    exclude = "  Exclude: ",
  }

  local prefix = prefixes[field_name]
  if not prefix then
    return
  end

  -- Get value from buffer (0-indexed)
  local value = get_line_value(buf, line_num - 1, prefix)

  state.update_input(field_name, value)
end

---Trigger search with current inputs (debounced)
local function trigger_search()
  local config = require("wherewolf.config").get()
  local boundaries = require("wherewolf.ui.boundaries")

  -- Don't trigger if already searching (prevent infinite loop)
  if state.current.is_searching then
    return
  end

  -- Cancel existing timer
  if state.current.debounce_timer then
    state.current.debounce_timer:stop()
    state.current.debounce_timer:close()
    state.current.debounce_timer = nil
  end

  -- Create new timer (using vim.loop for proper cancellable timer)
  local timer = vim.loop.new_timer()
  state.current.debounce_timer = timer

  timer:start(config.debounce_ms, 0, vim.schedule_wrap(function()
    -- Clear the timer reference
    state.current.debounce_timer = nil
    timer:stop()
    timer:close()

    -- Double-check we're not already searching
    if state.current.is_searching then
      return
    end

    -- Get current input values from buffer
    local buf = state.current.buf
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    local current_inputs = boundaries.get_all_inputs(buf)

    -- VALUE CHANGE DETECTION: Only trigger if inputs actually changed
    if state.current.last_inputs and vim.deep_equal(current_inputs, state.current.last_inputs) then
      return
    end

    -- Update state with new values
    state.current.inputs = current_inputs
    state.current.last_inputs = vim.deepcopy(current_inputs)

    -- Skip if search pattern is empty
    if current_inputs.search == "" then
      return
    end

    -- Trigger search
    require("wherewolf.ui").perform_search()
  end))
end

---Setup autocmds for live input updates
---@param buf number Buffer handle
local function setup_autocmds(buf)
  local augroup = vim.api.nvim_create_augroup('WherewolfInput', { clear = true })

  -- Track text changes in buffer
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    buffer = buf,
    callback = function()
      -- GUARD #1: Skip if this is a programmatic update
      if state.current.update_disabled then
        return
      end

      -- Get current line (1-indexed)
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]

      -- Check if we're in an input field
      local field_num = state.get_field_from_line(line_num)
      if not field_num then
        return
      end

      -- Sync input value to state (for backwards compatibility)
      local field_name = state.get_field_name(field_num)
      if field_name then
        sync_input_from_buffer(buf, field_name)
        -- Trigger search (with built-in value change detection)
        trigger_search()
      end
    end,
    desc = 'Wherewolf: Track input changes',
  })

  -- Keep cursor in input fields
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    buffer = buf,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]

      -- Determine last input line (exclude if advanced, else replace)
      local last_input_line = state.input_lines.exclude or state.input_lines.replace

      -- If cursor is on a non-input line, move it to search field
      if line_num < state.input_lines.search or line_num > last_input_line then
        if line_num > last_input_line then
          -- Don't interfere with results navigation
          return
        end
        -- Move to search field
        vim.api.nvim_win_set_cursor(0, { state.input_lines.search, 11 })
      end
    end,
    desc = 'Wherewolf: Keep cursor in valid area',
  })
end

---Navigate to next input field
---@param buf number Buffer handle
function M.next_field(buf)
  -- Get current field
  local current = state.current.current_field

  -- Determine max field (2 if not showing advanced, 4 if showing)
  local max_field = state.current.show_advanced and 4 or 2

  -- Calculate next field (wrap around)
  local next_field = current + 1
  if next_field > max_field then
    next_field = 1
  end

  -- Update state
  state.current.current_field = next_field

  -- Move cursor to field line
  local line_num = state.get_line_for_field(next_field)
  if line_num then
    -- Position cursor at end of line
    local lines = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)
    local line_length = #lines[1]
    vim.api.nvim_win_set_cursor(0, { line_num, line_length })
  end
end

---Navigate to previous input field
---@param buf number Buffer handle
function M.prev_field(buf)
  -- Get current field
  local current = state.current.current_field

  -- Determine max field (2 if not showing advanced, 4 if showing)
  local max_field = state.current.show_advanced and 4 or 2

  -- Calculate previous field (wrap around)
  local prev_field = current - 1
  if prev_field < 1 then
    prev_field = max_field
  end

  -- Update state
  state.current.current_field = prev_field

  -- Move cursor to field line
  local line_num = state.get_line_for_field(prev_field)
  if line_num then
    -- Position cursor at end of line
    local lines = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)
    local line_length = #lines[1]
    vim.api.nvim_win_set_cursor(0, { line_num, line_length })
  end
end

---Setup input field system
---@param buf number Buffer handle
function M.setup(buf)
  -- Setup autocmds for live updates
  setup_autocmds(buf)

  -- Initialize cursor position to search field
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      local line_num = state.input_lines.search
      vim.api.nvim_win_set_cursor(0, { line_num, 11 }) -- After "  Pattern: "
      vim.cmd('startinsert!')
    end
  end)
end

---Clear all input fields
---@param buf number Buffer handle
function M.clear_all(buf)
  local boundaries = require("wherewolf.ui.boundaries")

  -- Clear state
  state.current.inputs = {
    search = "",
    replace = "",
    include = "",
    exclude = "",
  }
  state.current.last_inputs = vim.deepcopy(state.current.inputs)

  -- Update buffer using safe wrapper
  state.current.update_disabled = true

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  lines[state.input_lines.search] = "  Pattern: "
  lines[state.input_lines.replace] = "  Replace: "
  if state.input_lines.include then
    lines[state.input_lines.include] = "  Files:   "
  end
  if state.input_lines.exclude then
    lines[state.input_lines.exclude] = "  Exclude: "
  end

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.schedule(function()
    state.current.update_disabled = false
  end)

  -- Move cursor to search field
  vim.api.nvim_win_set_cursor(0, { state.input_lines.search, 11 })
end

return M
