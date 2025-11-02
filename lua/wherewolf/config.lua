-- Configuration management for wherewolf.nvim

local M = {}

---@class WherewolfConfig
---@field search_engine "ripgrep"|"ast-grep"
---@field case_sensitive boolean
---@field multiline boolean
---@field max_results number
---@field debounce_ms number
---@field ui WherewolfUIConfig
---@field rg WherewolfRgConfig

---@class WherewolfUIConfig
---@field position "left"|"right"
---@field width number|string
---@field show_include_exclude boolean
---@field auto_focus boolean

---@class WherewolfRgConfig
---@field extra_args string[]
---@field respect_gitignore boolean
---@field hidden boolean

M.defaults = {
  search_engine = "ripgrep",
  case_sensitive = false,
  multiline = false,
  max_results = 1000,
  debounce_ms = 500,  -- Wait 500ms after user stops typing

  ui = {
    position = "right",       -- "left" or "right"
    width = 50,               -- Width in columns or percentage as string "30%"
    show_include_exclude = false,  -- Show include/exclude fields by default
    auto_focus = true,        -- Auto focus sidebar when opened
  },

  rg = {
    extra_args = {},          -- Extra ripgrep arguments
    respect_gitignore = true, -- Respect .gitignore files
    hidden = false,           -- Search hidden files
  },
}

---@type WherewolfConfig
M.options = {}

---Setup configuration with user options
---@param opts? WherewolfConfig User configuration
---@return WherewolfConfig
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
  return M.options
end

---Get current configuration
---@return WherewolfConfig
function M.get()
  if vim.tbl_isempty(M.options) then
    return M.setup()
  end
  return M.options
end

return M
