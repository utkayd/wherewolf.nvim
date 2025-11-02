-- Sidebar management for wherewolf.nvim

local Split = require("nui.split")
local state = require("wherewolf.ui.state")
local highlights = require("wherewolf.ui.highlights")

local M = {}

---Create sidebar buffer with proper settings
---@param buf number Buffer handle
local function setup_buffer(buf)
  -- Buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'wherewolf')
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)

  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, 'wherewolf://search')
end

---Initialize buffer content with input fields
---@param buf number Buffer handle
local function init_buffer_content(buf)
  local boundaries = require("wherewolf.ui.boundaries")
  local show_advanced = state.current.show_advanced
  local inputs = state.get_inputs()

  -- Buffer lines now contain ONLY the input values (labels are virtual text)
  -- Each input field is wrapped in a compact rounded border (noice.nvim style)
  local lines = {
    "╭──────────────────────────────────────────────────╮",
    inputs.search,    -- Line 1: search value only
    "╰──────────────────────────────────────────────────╯",
    "",
    "╭──────────────────────────────────────────────────╮",
    inputs.replace,   -- Line 5: replace value only
    "╰──────────────────────────────────────────────────╯",
  }

  -- Update input line numbers (for backwards compatibility)
  state.input_lines.search = 2
  state.input_lines.replace = 6

  if show_advanced then
    table.insert(lines, "")
    table.insert(lines, "╭──────────────────────────────────────────────────╮")
    table.insert(lines, inputs.include)   -- include value only
    table.insert(lines, "╰──────────────────────────────────────────────────╯")
    table.insert(lines, "")
    table.insert(lines, "╭──────────────────────────────────────────────────╮")
    table.insert(lines, inputs.exclude)   -- exclude value only
    table.insert(lines, "╰──────────────────────────────────────────────────╯")
    state.input_lines.include = 10
    state.input_lines.exclude = 14
    state.input_lines.results_start = 18  -- Line 18 (1-indexed) = index 17 (0-indexed)
  else
    -- Hide advanced fields by setting them to nil
    state.input_lines.include = nil
    state.input_lines.exclude = nil
    state.input_lines.results_start = 10  -- Line 10 (1-indexed) = index 9 (0-indexed)
  end
  table.insert(lines, "")
  table.insert(lines, "")
  table.insert(lines, "  No results yet. Start typing to search...")
  table.insert(lines, "")

  -- Set buffer content using safe wrapper
  boundaries.set_buf_lines_safe(buf, 0, -1, lines)

  -- Setup extmark boundaries AFTER buffer has content
  -- The extmarks will add virtual text labels that appear before the values
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      state.current.extmark_ids = boundaries.setup_boundaries(buf)
    end
  end)
end

---Refresh buffer content (used when toggling advanced fields)
---@param buf number Buffer handle
function M.refresh_content(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Save current results
  local results = state.get_results()

  -- Rebuild buffer content (this will also re-setup extmark boundaries)
  init_buffer_content(buf)

  -- Redisplay results if any (scheduled to ensure extmarks are ready)
  if #results > 0 then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        require("wherewolf.ui.results").display(buf, results)
      end
    end)
  end
end

---Create and mount the sidebar split
---@return table split nui.Split instance
function M.create()
  local config = require("wherewolf.config").get()

  -- Determine split position command
  local position_cmd
  if config.ui.position == "left" then
    position_cmd = "topleft vsplit"
  else
    position_cmd = "botright vsplit"
  end

  -- Calculate width
  local width = config.ui.width
  if type(width) == "string" and width:match("%%$") then
    local percentage = tonumber(width:match("(%d+)%%"))
    if percentage then
      width = math.floor(vim.o.columns * percentage / 100)
    end
  end

  -- Create split
  local split = Split({
    relative = "editor",
    position = config.ui.position,
    size = width,
    enter = config.ui.auto_focus,
    buf_options = {
      buftype = "nofile",
      swapfile = false,
      filetype = "wherewolf",
    },
    win_options = {
      number = false,
      relativenumber = false,
      cursorline = false,
      wrap = false,
      spell = false,
      signcolumn = "no",
    },
  })

  -- Mount the split
  split:mount()

  -- Get buffer handle
  local buf = split.bufnr

  -- Setup buffer
  setup_buffer(buf)
  init_buffer_content(buf)

  -- Store in state
  state.current.split = split
  state.current.buf = buf
  state.current.win = split.winid

  return split
end

---Open the sidebar (create if doesn't exist)
function M.open()
  if state.is_open() then
    -- Already open, just focus
    if state.current.split.winid then
      vim.api.nvim_set_current_win(state.current.split.winid)
    end
    return
  end

  -- Initialize show_advanced from config if not set
  if state.current.show_advanced == nil then
    local config = require("wherewolf.config").get()
    state.current.show_advanced = config.ui.show_include_exclude
  end

  -- Create new sidebar
  M.create()

  -- Setup keymaps
  require("wherewolf.ui.keymaps").setup(state.current.buf)

  -- Setup inputs
  require("wherewolf.ui.inputs").setup(state.current.buf)

  -- Force focus to Pattern field (double schedule to ensure it runs last)
  vim.schedule(function()
    vim.schedule(function()
      if state.current.win and vim.api.nvim_win_is_valid(state.current.win) then
        vim.api.nvim_set_current_win(state.current.win)
        -- Position cursor on Pattern field (line 2, 1-indexed)
        vim.api.nvim_win_set_cursor(state.current.win, { 2, 0 })
        vim.cmd('startinsert!')
      end
    end)
  end)
end

---Close the sidebar
function M.close()
  if not state.is_open() then
    return
  end

  -- Unmount split
  if state.current.split then
    state.current.split:unmount()
  end

  -- Clear state
  state.current.split = nil
  state.current.buf = nil
  state.current.win = nil
end

---Toggle sidebar visibility
function M.toggle()
  if state.is_open() then
    M.close()
  else
    M.open()
  end
end

---Focus the sidebar window
function M.focus()
  if state.is_open() and state.current.split.winid then
    vim.api.nvim_set_current_win(state.current.split.winid)
  end
end

---Check if sidebar is currently focused
---@return boolean
function M.is_focused()
  if not state.is_open() then
    return false
  end
  return vim.api.nvim_get_current_win() == state.current.split.winid
end

return M
