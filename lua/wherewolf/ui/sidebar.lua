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
  local lines = {
    "╔══════════════════════════════════════════════════╗",
    "  Pattern: ",
    "  Replace: ",
    "  Files:   ",
    "  Exclude: ",
    "╠══════════════════════════════════════════════════╣",
    "",
    "  No results yet. Start typing to search...",
    "",
  }

  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
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
      cursorline = true,
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

  -- Create new sidebar
  M.create()

  -- Setup keymaps
  require("wherewolf.ui.keymaps").setup(state.current.buf)

  -- Setup inputs
  require("wherewolf.ui.inputs").setup(state.current.buf)
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
