-- State management for wherewolf.nvim UI

local M = {}

---@class WherewolfInputFields
---@field search string Pattern to search for
---@field replace string Replacement text
---@field include string Files to include
---@field exclude string Files to exclude

---@class WherewolfUIState
---@field split? table nui.nvim Split instance
---@field buf? number Buffer handle
---@field win? number Window handle
---@field inputs WherewolfInputFields Input field values
---@field results table[] Search results
---@field current_field number Currently focused input field (1-4)
---@field show_advanced boolean Show include/exclude fields
---@field is_searching boolean Whether a search is in progress
---@field debounce_timer? table Timer for debouncing
---@field search_job_id? number Current search job ID
---@field update_disabled boolean Guard flag to prevent infinite loops during programmatic updates
---@field last_inputs? WherewolfInputFields Last input values to detect changes
---@field extmark_ids? table Extmark IDs for boundary tracking

---@type WherewolfUIState
M.current = {
  split = nil,
  buf = nil,
  win = nil,
  inputs = {
    search = "",
    replace = "",
    include = "",
    exclude = "",
  },
  results = {},
  current_field = 1,
  show_advanced = nil,  -- Will be set from config on first open
  is_searching = false,
  debounce_timer = nil,
  search_job_id = nil,  -- Track current search job to cancel it
  update_disabled = false,  -- Guard flag for programmatic updates
  last_inputs = nil,  -- Track last input values
  extmark_ids = {},  -- Extmark IDs for boundaries
}

---Input field line numbers in the buffer
M.input_lines = {
  search = 2,    -- Line 2: Search pattern
  replace = 3,   -- Line 3: Replace pattern
  include = 4,   -- Line 4: Files to include (toggleable)
  exclude = 5,   -- Line 5: Files to exclude (toggleable)
  results_start = 7, -- Line 7: Where results begin
}

---Reset state to defaults
function M.reset()
  M.current.inputs = {
    search = "",
    replace = "",
    include = "",
    exclude = "",
  }
  M.current.results = {}
  M.current.current_field = 1
  M.current.is_searching = false

  -- Cancel any pending debounce timer
  if M.current.debounce_timer then
    M.current.debounce_timer:close()
    M.current.debounce_timer = nil
  end

  -- Stop any running search job (handled by search module now)
  local search_module = require("wherewolf.search")
  if search_module._current_search_obj then
    pcall(function() search_module._current_search_obj:kill(15) end)
    search_module._current_search_obj = nil
  end
  M.current.search_job_id = nil
end

---Check if sidebar is currently open
---@return boolean
function M.is_open()
  return M.current.split ~= nil
    and M.current.split.winid ~= nil
    and vim.api.nvim_win_is_valid(M.current.split.winid)
end

---Check if buffer is valid
---@return boolean
function M.is_buf_valid()
  return M.current.buf ~= nil and vim.api.nvim_buf_is_valid(M.current.buf)
end

---Get input field name from field number
---@param field_num number Field number (1-4)
---@return string? field_name Field name or nil
function M.get_field_name(field_num)
  local fields = { "search", "replace", "include", "exclude" }
  return fields[field_num]
end

---Get field number from line number
---@param line_num number Line number in buffer
---@return number? field_num Field number or nil
function M.get_field_from_line(line_num)
  for i, field_name in ipairs({ "search", "replace", "include", "exclude" }) do
    if M.input_lines[field_name] == line_num then
      return i
    end
  end
  return nil
end

---Get line number for input field
---@param field_num number Field number (1-4)
---@return number? line_num Line number or nil
function M.get_line_for_field(field_num)
  local field_name = M.get_field_name(field_num)
  if field_name then
    return M.input_lines[field_name]
  end
  return nil
end

---Update input field value
---@param field_name string Field name (search, replace, include, exclude)
---@param value string New value
function M.update_input(field_name, value)
  if M.current.inputs[field_name] ~= nil then
    M.current.inputs[field_name] = value
  end
end

---Get all input values
---@return WherewolfInputFields
function M.get_inputs()
  return M.current.inputs
end

---Set search results
---@param results table[] Search results
function M.set_results(results)
  M.current.results = results
end

---Get search results
---@return table[]
function M.get_results()
  return M.current.results
end

return M
