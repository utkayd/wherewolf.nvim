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

---Get the width of the window or use default
---@param win number|nil Window handle
---@return number width Window width
local function get_window_width(win)
  if win and vim.api.nvim_win_is_valid(win) then
    local width = vim.api.nvim_win_get_width(win)
    -- Ensure we have a reasonable minimum and maximum
    if width < 30 then
      width = 30
    elseif width > 200 then
      width = 200
    end
    return width
  end
  return 52  -- Default fallback width
end

---Generate border line of specified width
---@param char string Border character (─ for horizontal)
---@param left string Left corner character
---@param right string Right corner character
---@param width number Total width
---@return string border_line
local function make_border_line(left, char, right, width)
  local inner_width = width - 2  -- Subtract 2 for left and right corners
  return left .. string.rep(char, inner_width) .. right
end

---Generate top border with embedded label (cmdline style)
---@param label string Label text (e.g., "Pattern", "Replace")
---@param width number Total width
---@return string border_line
local function make_top_border_with_label(label, width)
  -- Ensure width is valid
  if width < 10 then
    width = 10
  end

  local label_with_spaces = " " .. label .. " "
  local label_width = vim.fn.strwidth(label_with_spaces)
  local remaining = width - 2 - label_width  -- Subtract corners and label

  if remaining < 0 then
    -- Fallback if window is too narrow - just make a plain border
    return make_border_line("╭", "─", "╮", width)
  end

  -- Put label immediately after left corner (no dashes on left)
  return "╭" .. label_with_spaces .. string.rep("─", remaining) .. "╮"
end

---Initialize buffer content with input fields
---@param buf number Buffer handle
local function init_buffer_content(buf)
  local boundaries = require("wherewolf.ui.boundaries")
  local show_advanced = state.current.show_advanced
  local inputs = state.get_inputs()

  -- Get current window width for dynamic borders
  local width = get_window_width(state.current.win)

  -- Account for any padding or edge cases - make borders fit comfortably
  -- The -2 ensures we don't overflow the window width
  width = math.max(30, width - 2)

  -- Buffer lines now contain ONLY the input values
  -- Each input field is wrapped in a compact rounded border with label in border (cmdline style)
  local bottom_border = make_border_line("╰", "─", "╯", width)

  local lines = {
    make_top_border_with_label("Pattern", width),
    inputs.search,    -- Line 1: search value only
    bottom_border,
    "",
    make_top_border_with_label("Replace", width),
    inputs.replace,   -- Line 5: replace value only
    bottom_border,
  }

  -- Update input line numbers (for backwards compatibility)
  state.input_lines.search = 2
  state.input_lines.replace = 6

  if show_advanced then
    table.insert(lines, "")
    table.insert(lines, make_top_border_with_label("Files", width))
    table.insert(lines, inputs.include)   -- include value only
    table.insert(lines, bottom_border)
    table.insert(lines, "")
    table.insert(lines, make_top_border_with_label("Exclude", width))
    table.insert(lines, inputs.exclude)   -- exclude value only
    table.insert(lines, bottom_border)
    state.input_lines.include = 10
    state.input_lines.exclude = 14
    state.input_lines.results_start = 18  -- Line 18 (1-indexed) = index 17 (0-indexed)
  else
    -- Hide advanced fields by setting them to nil
    state.input_lines.include = nil
    state.input_lines.exclude = nil
    state.input_lines.results_start = 10  -- Line 10 (1-indexed) = index 9 (0-indexed)
  end

  -- Store current width in state for boundaries to access
  state.current.window_width = width
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
      -- Apply syntax highlighting to border characters for consistent coloring
      vim.cmd([[
        syntax match WherewolfBorderChar /[╭╮╰╯─│]/
        highlight default link WherewolfBorderChar WherewolfBorder
        syntax match WherewolfBorderLabel /╭\s\zs\w\+\ze\s/
        highlight default link WherewolfBorderLabel WherewolfInputLabel
      ]])
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

  -- Store in state FIRST (needed for width calculation)
  state.current.split = split
  state.current.buf = buf
  state.current.win = split.winid

  -- Setup buffer (now that state.current.win is available)
  setup_buffer(buf)
  init_buffer_content(buf)

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

  -- Setup resize handler to update borders dynamically
  local augroup = vim.api.nvim_create_augroup('WherewolfResize', { clear = true })
  vim.api.nvim_create_autocmd({ 'WinResized' }, {
    group = augroup,
    callback = function()
      -- Only handle resize for wherewolf window
      if state.current.win and vim.api.nvim_win_is_valid(state.current.win) then
        local resized_wins = vim.v.event.windows or {}
        for _, win_id in ipairs(resized_wins) do
          if win_id == state.current.win then
            -- Window was resized, refresh content
            vim.schedule(function()
              if state.is_buf_valid() then
                M.refresh_content(state.current.buf)
              end
            end)
            break
          end
        end
      end
    end,
    desc = 'Wherewolf: Handle window resize',
  })

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

  -- Clean up resize autocmd
  pcall(vim.api.nvim_del_augroup_by_name, 'WherewolfResize')

  -- Clear state
  state.current.split = nil
  state.current.buf = nil
  state.current.win = nil
  state.current.window_width = nil
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
