-- Main entry point for wherewolf.nvim

local M = {}

-- Lazy load modules
local config = require("wherewolf.config")
local ui = nil

---Initialize UI module (lazy loaded)
local function get_ui()
  if not ui then
    ui = require("wherewolf.ui")
    ui.init()
  end
  return ui
end

---Setup wherewolf with user configuration
---@param opts? WherewolfConfig User configuration
function M.setup(opts)
  config.setup(opts)
end

---Open wherewolf sidebar
function M.open()
  get_ui().open()
end

---Close wherewolf sidebar
function M.close()
  get_ui().close()
end

---Toggle wherewolf sidebar
function M.toggle()
  get_ui().toggle()
end

---Search for a pattern
---@param pattern string Search pattern
---@param opts? table Options
function M.search(pattern, opts)
  opts = opts or {}

  -- Open UI
  get_ui().open()

  -- Set search pattern
  if pattern and pattern ~= "" then
    get_ui().set_search(pattern)
  end

  -- Focus search field
  get_ui().focus_field(1)
end

---Search and replace
---@param pattern string Search pattern
---@param replacement string Replacement text
---@param opts? table Options
function M.replace(pattern, replacement, opts)
  opts = opts or {}

  -- Open UI
  get_ui().open()

  -- Set search and replace
  if pattern and pattern ~= "" then
    get_ui().set_search(pattern)
  end

  if replacement and replacement ~= "" then
    get_ui().set_replace(replacement)
  end

  -- Focus search field
  get_ui().focus_field(1)
end

---Search for the word under cursor
function M.search_word()
  local word = vim.fn.expand('<cword>')
  if word and word ~= "" then
    M.search(word)
  else
    vim.notify("No word under cursor", vim.log.levels.WARN)
  end
end

---Search for visual selection
function M.search_visual()
  -- Get visual selection
  local _, start_row, start_col, _ = unpack(vim.fn.getpos("'<"))
  local _, end_row, end_col, _ = unpack(vim.fn.getpos("'>"))

  -- Get lines
  local lines = vim.api.nvim_buf_get_lines(0, start_row - 1, end_row, false)

  if #lines == 0 then
    vim.notify("No selection", vim.log.levels.WARN)
    return
  end

  -- Extract selected text
  local selection
  if #lines == 1 then
    -- Single line selection
    selection = lines[1]:sub(start_col, end_col)
  else
    -- Multi-line selection
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    selection = table.concat(lines, "\n")
  end

  if selection and selection ~= "" then
    M.search(selection)
  else
    vim.notify("No selection", vim.log.levels.WARN)
  end
end

---Apply replacements
function M.apply_replacements()
  get_ui().apply_replacements()
end

---Handle command subcommands
---@param opts table Command options from nvim_create_user_command
function M.handle_command(opts)
  local args = opts.fargs
  local subcommand = args[1]

  if subcommand == "toggle" then
    M.toggle()
  elseif subcommand == "open" then
    M.open()
  elseif subcommand == "close" then
    M.close()
  elseif subcommand == "search" then
    if args[2] then
      M.search(args[2])
    else
      M.search("")
    end
  elseif subcommand == "replace" then
    if args[2] and args[3] then
      M.replace(args[2], args[3])
    else
      vim.notify("Usage: Wherewolf replace <pattern> <replacement>", vim.log.levels.ERROR)
    end
  else
    vim.notify("Unknown subcommand: " .. subcommand, vim.log.levels.ERROR)
    vim.notify("Available: toggle, open, close, search, replace", vim.log.levels.INFO)
  end
end

-- Auto-initialize with defaults
if vim.tbl_isempty(config.options) then
  config.setup()
end

return M
