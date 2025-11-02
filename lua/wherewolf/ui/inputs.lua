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
---@return string value Input value
local function get_line_value(buf, line_num)
  local lines = vim.api.nvim_buf_get_lines(buf, line_num, line_num + 1, false)
  if #lines == 0 then
    return ""
  end

  -- Since labels are now virtual text, the buffer contains only the value
  return lines[1]
end

---Update input value in state from buffer
---@param buf number Buffer handle
---@param field_name string Field name (search, replace, include, exclude)
local function sync_input_from_buffer(buf, field_name)
  local line_num = state.input_lines[field_name]
  if not line_num then
    return
  end

  -- Get value from buffer (0-indexed)
  local value = get_line_value(buf, line_num - 1)

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

  -- Protect input lines from being deleted
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function(_, buf, _, first_line, _, last_line)
      -- Skip if this is a programmatic update
      if state.current.update_disabled then
        return
      end

      -- Check if any input lines were deleted
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end

        -- Get all input line numbers (0-indexed for comparison)
        local input_line_nums = {
          state.input_lines.search and (state.input_lines.search - 1),
          state.input_lines.replace and (state.input_lines.replace - 1),
          state.input_lines.include and (state.input_lines.include - 1),
          state.input_lines.exclude and (state.input_lines.exclude - 1),
        }

        -- Check if any input line is missing or was deleted
        local total_lines = vim.api.nvim_buf_line_count(buf)
        local needs_restore = false

        for _, line_num in ipairs(input_line_nums) do
          if line_num and line_num < total_lines then
            local lines = vim.api.nvim_buf_get_lines(buf, line_num, line_num + 1, false)
            -- If the line doesn't exist, mark for restore
            if #lines == 0 or lines[1] == nil then
              needs_restore = true
              break
            end
          elseif line_num and line_num >= total_lines then
            -- Line number is beyond buffer, needs restore
            needs_restore = true
            break
          end
        end

        if needs_restore then
          -- Restore entire buffer structure
          local boundaries = require("wherewolf.ui.boundaries")
          state.current.update_disabled = true

          -- Get current input values before restoration
          local current_search = state.current.inputs.search or ""
          local current_replace = state.current.inputs.replace or ""
          local current_include = state.current.inputs.include or ""
          local current_exclude = state.current.inputs.exclude or ""

          -- Rebuild input area with compact rounded borders (cmdline style)
          -- Get current window width for dynamic borders
          local width = state.current.window_width or 52

          -- Ensure width is reasonable
          if width < 10 then
            width = 10
          end

          local function make_bottom_border()
            return "╰" .. string.rep("─", width - 2) .. "╯"
          end

          local function make_top_border_with_label(label)
            local label_with_spaces = " " .. label .. " "
            local label_width = vim.fn.strwidth(label_with_spaces)
            local remaining = width - 2 - 1 - label_width  -- Subtract corners, one dash, and label
            if remaining < 0 then
              return "╰" .. string.rep("─", width - 2) .. "╯"
            end
            -- Put label one dash after left corner
            return "╭─" .. label_with_spaces .. string.rep("─", remaining) .. "╮"
          end

          local bottom_border = make_bottom_border()

          local lines = {
            make_top_border_with_label("Pattern"),
            current_search,
            bottom_border,
            "",
            make_top_border_with_label("Replace"),
            current_replace,
            bottom_border,
          }

          if state.current.show_advanced then
            table.insert(lines, "")
            table.insert(lines, make_top_border_with_label("Files"))
            table.insert(lines, current_include)
            table.insert(lines, bottom_border)
            table.insert(lines, "")
            table.insert(lines, make_top_border_with_label("Exclude"))
            table.insert(lines, current_exclude)
            table.insert(lines, bottom_border)
          end

          -- Get existing results
          local results_start = boundaries.get_results_start_row(buf)
          local existing_results = vim.api.nvim_buf_get_lines(buf, results_start, -1, false)

          -- Append existing results
          vim.list_extend(lines, existing_results)

          -- Restore buffer
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

          -- Re-setup extmark boundaries after restoration
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(buf) then
              state.current.extmark_ids = boundaries.setup_boundaries(buf)
            end
            state.current.update_disabled = false
          end)
        end
      end)
    end,
  })

  -- Prevent backspace from deleting input lines in insert mode
  vim.api.nvim_buf_set_keymap(buf, 'i', '<BS>', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]
      local col = cursor[2]

      -- Check if we're in an input field
      local field_num = state.get_field_from_line(line_num)
      if field_num then
        -- If at column 0, don't allow backspace (would merge with previous line)
        if col == 0 then
          return
        end
        -- Otherwise, normal backspace
        local keys = vim.api.nvim_replace_termcodes('<BS>', true, false, true)
        vim.api.nvim_feedkeys(keys, 'n', false)
      end
    end,
    desc = 'Wherewolf: Protected backspace',
  })

  -- Prevent normal mode deletions of input lines
  vim.api.nvim_buf_set_keymap(buf, 'n', 'dd', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]
      -- Bottom border is 2 lines before results_start (results_start - 1 is empty line)
      local bottom_border_line = state.input_lines.results_start - 2

      -- Check if we're in the protected input area (first border to last border)
      if line_num >= 1 and line_num <= bottom_border_line then
        -- Check if we're on an actual input field
        local field_num = state.get_field_from_line(line_num)
        if field_num then
          -- On input field, just clear the content instead of deleting
          local boundaries = require("wherewolf.ui.boundaries")
          boundaries.set_buf_lines_safe(buf, line_num - 1, line_num, {""})
        end
        -- On border/empty lines, do nothing (protected)
        return
      end

      -- In results area, allow normal deletion
      local keys = vim.api.nvim_replace_termcodes('dd', true, false, true)
      vim.api.nvim_feedkeys(keys, 'n', false)
    end,
    desc = 'Wherewolf: Protected line deletion',
  })

  -- Prevent D (delete to end of line) on protected lines
  vim.api.nvim_buf_set_keymap(buf, 'n', 'D', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]
      local bottom_border_line = state.input_lines.results_start - 2
      local field_num = state.get_field_from_line(line_num)

      if field_num then
        -- In input field, allow D
        local keys = vim.api.nvim_replace_termcodes('D', true, false, true)
        vim.api.nvim_feedkeys(keys, 'n', false)
      elseif line_num >= 1 and line_num <= bottom_border_line then
        -- On border/padding lines, don't allow D
        return
      else
        -- In results area, allow normal D
        local keys = vim.api.nvim_replace_termcodes('D', true, false, true)
        vim.api.nvim_feedkeys(keys, 'n', false)
      end
    end,
    desc = 'Wherewolf: Protected D command',
  })

  -- Prevent C (change line) from deleting input lines
  vim.api.nvim_buf_set_keymap(buf, 'n', 'cc', '', {
    noremap = true,
    silent = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]
      local bottom_border_line = state.input_lines.results_start - 2
      local field_num = state.get_field_from_line(line_num)

      if field_num then
        -- In input field, clear and enter insert mode
        local boundaries = require("wherewolf.ui.boundaries")
        boundaries.set_buf_lines_safe(buf, line_num - 1, line_num, {""})
        vim.cmd('startinsert')
      elseif line_num >= 1 and line_num <= bottom_border_line then
        -- On border/padding lines, don't allow cc
        return
      else
        -- In results area, allow normal cc
        local keys = vim.api.nvim_replace_termcodes('cc', true, false, true)
        vim.api.nvim_feedkeys(keys, 'n', false)
      end
    end,
    desc = 'Wherewolf: Protected change line',
  })

  -- Prevent visual mode deletion of input lines
  vim.api.nvim_buf_set_keymap(buf, 'v', 'd', '', {
    noremap = true,
    silent = true,
    callback = function()
      local start_pos = vim.fn.getpos("'<")
      local end_pos = vim.fn.getpos("'>")
      local start_line = start_pos[2]
      local end_line = end_pos[2]

      -- Check if selection includes any protected lines (header to bottom border, inclusive)
      local bottom_border_line = state.input_lines.results_start - 2  -- Line before empty line

      for line = start_line, end_line do
        if line >= 1 and line <= bottom_border_line then
          -- Selection includes protected area (all input UI), don't allow deletion
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
          vim.notify('Cannot delete input fields or structure', vim.log.levels.WARN)
          return
        end
      end

      -- Safe to delete in results area
      local keys = vim.api.nvim_replace_termcodes('d', true, false, true)
      vim.api.nvim_feedkeys(keys, 'x', false)
    end,
    desc = 'Wherewolf: Protected visual deletion',
  })

  -- Also protect visual mode 'c' (change)
  vim.api.nvim_buf_set_keymap(buf, 'v', 'c', '', {
    noremap = true,
    silent = true,
    callback = function()
      local start_pos = vim.fn.getpos("'<")
      local end_pos = vim.fn.getpos("'>")
      local start_line = start_pos[2]
      local end_line = end_pos[2]

      -- Check if selection includes any protected lines (header to bottom border, inclusive)
      local bottom_border_line = state.input_lines.results_start - 2  -- Line before empty line

      for line = start_line, end_line do
        if line >= 1 and line <= bottom_border_line then
          -- Selection includes protected area, don't allow change
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
          vim.notify('Cannot modify input field structure', vim.log.levels.WARN)
          return
        end
      end

      -- Safe to change in results area
      local keys = vim.api.nvim_replace_termcodes('c', true, false, true)
      vim.api.nvim_feedkeys(keys, 'x', false)
    end,
    desc = 'Wherewolf: Protected visual change',
  })

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

  -- Handle mode changes (insert to normal) to fix empty field cursor position
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = augroup,
    buffer = buf,
    callback = function(ev)
      -- Only handle insert -> normal transitions
      if not (ev.match:match('^i') and ev.match:match('n$')) then
        return
      end

      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]
      local col = cursor[2]

      -- Check if on an input field
      local field_num = state.get_field_from_line(line_num)
      if not field_num then
        return
      end

      -- If on empty field at column 0, insert space
      local lines = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)
      if #lines > 0 and lines[1] == "" and col == 0 then
        local boundaries = require("wherewolf.ui.boundaries")
        boundaries.set_buf_lines_safe(buf, line_num - 1, line_num, { " " })
      end
    end,
    desc = 'Wherewolf: Handle mode change on empty fields',
  })

  -- Keep cursor in input fields (vertical restrictions and horizontal fix for empty fields)
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    buffer = buf,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]
      local col = cursor[2]
      local mode = vim.api.nvim_get_mode().mode

      -- Get list of valid input field lines
      local valid_input_lines = {
        state.input_lines.search,
        state.input_lines.replace,
      }
      if state.input_lines.include then
        table.insert(valid_input_lines, state.input_lines.include)
      end
      if state.input_lines.exclude then
        table.insert(valid_input_lines, state.input_lines.exclude)
      end

      -- Determine the last valid input line
      local last_input_line = valid_input_lines[#valid_input_lines]

      -- Don't interfere if cursor is in results area (below input fields)
      if line_num > last_input_line then
        return
      end

      -- Check if cursor is on a valid input line
      local is_valid = false
      for _, valid_line in ipairs(valid_input_lines) do
        if line_num == valid_line then
          is_valid = true
          break
        end
      end

      -- VERTICAL: If not on a valid input line, snap to nearest input line
      if not is_valid then
        local nearest_line = state.input_lines.search
        local min_distance = math.abs(line_num - nearest_line)

        for _, valid_line in ipairs(valid_input_lines) do
          local distance = math.abs(line_num - valid_line)
          if distance < min_distance then
            min_distance = distance
            nearest_line = valid_line
          end
        end

        -- Also insert space if navigating to empty field in normal mode
        if mode == 'n' then
          local lines = vim.api.nvim_buf_get_lines(buf, nearest_line - 1, nearest_line, false)
          if #lines > 0 and lines[1] == "" then
            local boundaries = require("wherewolf.ui.boundaries")
            boundaries.set_buf_lines_safe(buf, nearest_line - 1, nearest_line, { " " })
          end
        end

        vim.api.nvim_win_set_cursor(0, { nearest_line, cursor[2] })
      -- HORIZONTAL: If we're on a valid input line in normal mode with empty content, add space
      elseif mode == 'n' and is_valid then
        local lines = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)
        if #lines > 0 and lines[1] == "" and col == 0 then
          local boundaries = require("wherewolf.ui.boundaries")
          boundaries.set_buf_lines_safe(buf, line_num - 1, line_num, { " " })
        end
      end
    end,
    desc = 'Wherewolf: Keep cursor in valid area',
  })
end

---Navigate to next input field
---@param buf number Buffer handle
function M.next_field(buf)
  -- Get current cursor position to determine which field we're on
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  -- Build list of input field lines in order
  local input_lines = { state.input_lines.search, state.input_lines.replace }
  if state.current.show_advanced then
    table.insert(input_lines, state.input_lines.include)
    table.insert(input_lines, state.input_lines.exclude)
  end

  -- Find next input line
  local next_line = input_lines[1] -- Default to first field
  for i, line in ipairs(input_lines) do
    if current_line == line then
      -- Found current field, move to next (wrap around)
      next_line = input_lines[i + 1] or input_lines[1]
      break
    elseif current_line < line then
      -- Cursor is before this field, jump to it
      next_line = line
      break
    end
  end

  -- Move cursor to next field
  local lines = vim.api.nvim_buf_get_lines(buf, next_line - 1, next_line, false)
  local line_length = #(lines[1] or "")
  vim.api.nvim_win_set_cursor(0, { next_line, math.min(cursor[2], line_length) })

  -- Update state
  state.current.current_field = state.get_field_from_line(next_line) or 1
end

---Navigate to previous input field
---@param buf number Buffer handle
function M.prev_field(buf)
  -- Get current cursor position to determine which field we're on
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor[1]

  -- Build list of input field lines in order
  local input_lines = { state.input_lines.search, state.input_lines.replace }
  if state.current.show_advanced then
    table.insert(input_lines, state.input_lines.include)
    table.insert(input_lines, state.input_lines.exclude)
  end

  -- Find previous input line
  local prev_line = input_lines[#input_lines] -- Default to last field
  for i, line in ipairs(input_lines) do
    if current_line == line then
      -- Found current field, move to previous (wrap around)
      prev_line = input_lines[i - 1] or input_lines[#input_lines]
      break
    elseif current_line < line then
      -- Cursor is before this field, jump to previous field
      prev_line = input_lines[i - 1] or input_lines[#input_lines]
      break
    end
  end

  -- Move cursor to previous field
  local lines = vim.api.nvim_buf_get_lines(buf, prev_line - 1, prev_line, false)
  local line_length = #(lines[1] or "")
  vim.api.nvim_win_set_cursor(0, { prev_line, math.min(cursor[2], line_length) })

  -- Update state
  state.current.current_field = state.get_field_from_line(prev_line) or 1
end

---Setup input field system
---@param buf number Buffer handle
function M.setup(buf)
  -- Setup autocmds for live updates
  setup_autocmds(buf)

  -- Initialize cursor position to search field
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) and state.current.win then
      -- Focus the wherewolf window first
      if vim.api.nvim_win_is_valid(state.current.win) then
        vim.api.nvim_set_current_win(state.current.win)
      end

      local line_num = state.input_lines.search
      -- Cursor at start of line (label is virtual text, not real content)
      vim.api.nvim_win_set_cursor(0, { line_num, 0 })
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

  -- Update buffer using safe wrapper (labels are virtual text, so we just clear the values)
  state.current.update_disabled = true

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  lines[state.input_lines.search] = ""
  lines[state.input_lines.replace] = ""
  if state.input_lines.include then
    lines[state.input_lines.include] = ""
  end
  if state.input_lines.exclude then
    lines[state.input_lines.exclude] = ""
  end

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.schedule(function()
    state.current.update_disabled = false
  end)

  -- Move cursor to search field (start of line, since label is virtual text)
  vim.api.nvim_win_set_cursor(0, { state.input_lines.search, 0 })
end

return M
