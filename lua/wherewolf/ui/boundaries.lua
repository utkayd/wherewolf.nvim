-- Extmark-based boundary system for wherewolf.nvim
-- Based on grug-far.nvim's approach to separate inputs from results

local state = require("wherewolf.ui.state")

local M = {}

-- Namespaces for different purposes
M.ns_main = vim.api.nvim_create_namespace('wherewolf-main')  -- Boundaries and structure
M.ns_results = vim.api.nvim_create_namespace('wherewolf-results')  -- Results display
M.ns_hl = vim.api.nvim_create_namespace('wherewolf-highlight')  -- Syntax highlighting

---Setup extmark boundaries for inputs and results
---@param buf number Buffer handle
---@return table extmark_ids Table of extmark IDs
function M.setup_boundaries(buf)
  local extmarks = {}
  local show_advanced = state.current.show_advanced
  local highlights_mod = require("wherewolf.ui.highlights")

  -- Search input boundary (line 1, 0-indexed)
  -- Use virt_text to display the label inline (noice.nvim style)
  extmarks.search = vim.api.nvim_buf_set_extmark(buf, M.ns_main, 1, 0, {
    id = extmarks.search,  -- Reuse ID if it exists
    right_gravity = false,
    virt_text = {{ "│ ", "WherewolfBorder" }, { "Pattern: ", "WherewolfInputLabel" }},
    virt_text_pos = "inline",
    invalidate = false,  -- Don't invalidate on buffer changes
  })

  -- Right border for search input (at fixed column to match border width)
  vim.api.nvim_buf_set_extmark(buf, M.ns_main, 1, 0, {
    virt_text = {{ "│", "WherewolfBorder" }},
    virt_text_win_col = 51,  -- Position at column 51 (border is 52 chars wide, 0-indexed)
    invalidate = false,
  })

  -- Replace input boundary (line 5, 0-indexed)
  extmarks.replace = vim.api.nvim_buf_set_extmark(buf, M.ns_main, 5, 0, {
    id = extmarks.replace,
    right_gravity = false,
    virt_text = {{ "│ ", "WherewolfBorder" }, { "Replace: ", "WherewolfInputLabel" }},
    virt_text_pos = "inline",
    invalidate = false,
  })

  -- Right border for replace input (at fixed column)
  vim.api.nvim_buf_set_extmark(buf, M.ns_main, 5, 0, {
    virt_text = {{ "│", "WherewolfBorder" }},
    virt_text_win_col = 51,
    invalidate = false,
  })

  if show_advanced then
    -- Include input boundary (line 9, 0-indexed)
    extmarks.include = vim.api.nvim_buf_set_extmark(buf, M.ns_main, 9, 0, {
      id = extmarks.include,
      right_gravity = false,
      virt_text = {{ "│ ", "WherewolfBorder" }, { "Files:   ", "WherewolfInputLabel" }},
      virt_text_pos = "inline",
      invalidate = false,
    })

    -- Right border for include input (at fixed column)
    vim.api.nvim_buf_set_extmark(buf, M.ns_main, 9, 0, {
      virt_text = {{ "│", "WherewolfBorder" }},
      virt_text_win_col = 51,
      invalidate = false,
    })

    -- Exclude input boundary (line 13, 0-indexed)
    extmarks.exclude = vim.api.nvim_buf_set_extmark(buf, M.ns_main, 13, 0, {
      id = extmarks.exclude,
      right_gravity = false,
      virt_text = {{ "│ ", "WherewolfBorder" }, { "Exclude: ", "WherewolfInputLabel" }},
      virt_text_pos = "inline",
      invalidate = false,
    })

    -- Right border for exclude input (at fixed column)
    vim.api.nvim_buf_set_extmark(buf, M.ns_main, 13, 0, {
      virt_text = {{ "│", "WherewolfBorder" }},
      virt_text_win_col = 51,
      invalidate = false,
    })

    -- Results header (line 17, 0-indexed - where results actually start)
    extmarks.results_header = vim.api.nvim_buf_set_extmark(buf, M.ns_main, 17, 0, {
      id = extmarks.results_header,
      right_gravity = false,
      invalidate = false,
    })
  else
    -- Results header (line 9, 0-indexed - where results actually start)
    extmarks.results_header = vim.api.nvim_buf_set_extmark(buf, M.ns_main, 9, 0, {
      id = extmarks.results_header,
      right_gravity = false,
      invalidate = false,
    })
  end

  return extmarks
end

---Get the row where results start
---@param buf number Buffer handle
---@return number row Row number (0-indexed)
function M.get_results_start_row(buf)
  local extmark_id = state.current.extmark_ids.results_header
  if not extmark_id then
    return 9  -- Fallback (0-indexed, line 10 - where results actually display)
  end

  local pos = vim.api.nvim_buf_get_extmark_by_id(buf, M.ns_main, extmark_id, {})
  return pos[1]
end

---Get input field value from buffer using extmarks
---@param buf number Buffer handle
---@param field_name string Field name (search, replace, include, exclude)
---@return string value Field value
function M.get_input_value(buf, field_name)
  local extmarks = state.current.extmark_ids
  if not extmarks or not extmarks[field_name] then
    return ""
  end

  -- Determine the next boundary
  local next_field_map = {
    search = "replace",
    replace = state.current.show_advanced and "include" or "results_header",
    include = "exclude",
    exclude = "results_header",
  }

  local next_boundary = next_field_map[field_name]
  if not next_boundary or not extmarks[next_boundary] then
    return ""
  end

  -- Get row positions from extmarks
  local start_row = vim.api.nvim_buf_get_extmark_by_id(buf, M.ns_main, extmarks[field_name], {})[1]
  local end_row = vim.api.nvim_buf_get_extmark_by_id(buf, M.ns_main, extmarks[next_boundary], {})[1]

  -- Get lines between boundaries
  local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row, false)

  -- Since labels are now virtual text, the actual buffer content is just the value
  if #lines > 0 then
    return lines[1]
  end

  return ""
end

---Get all input values from buffer
---@param buf number Buffer handle
---@return WherewolfInputFields inputs All input field values
function M.get_all_inputs(buf)
  return {
    search = M.get_input_value(buf, "search"),
    replace = M.get_input_value(buf, "replace"),
    include = M.get_input_value(buf, "include"),
    exclude = M.get_input_value(buf, "exclude"),
  }
end

---Safe buffer modification wrapper (prevents autocmd triggers)
---@param buf number Buffer handle
---@param start_row number Start row (0-indexed)
---@param end_row number End row (0-indexed, -1 for end of buffer)
---@param lines string[] Lines to set
function M.set_buf_lines_safe(buf, start_row, end_row, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Set guard flag BEFORE modification
  state.current.update_disabled = true

  local was_modifiable = vim.api.nvim_get_option_value('modifiable', { buf = buf })

  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  pcall(vim.cmd.undojoin)  -- Try to join with previous undo
  vim.api.nvim_buf_set_lines(buf, start_row, end_row, false, lines)
  vim.api.nvim_set_option_value('modifiable', was_modifiable, { buf = buf })

  -- Clear guard flag AFTER event loop completes
  vim.schedule(function()
    state.current.update_disabled = false
  end)
end

---Clear results area (everything after results_header)
---@param buf number Buffer handle
function M.clear_results(buf)
  local results_row = M.get_results_start_row(buf)

  -- Clear result namespaces
  vim.api.nvim_buf_clear_namespace(buf, M.ns_results, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, M.ns_hl, 0, -1)

  -- Clear result lines (using safe wrapper)
  M.set_buf_lines_safe(buf, results_row, -1, {''})
end

return M
