-- Highlight groups for wherewolf.nvim UI

local M = {}

---Setup highlight groups for wherewolf UI
function M.setup()
  -- Title and header highlights
  vim.api.nvim_set_hl(0, 'WherewolfTitle', { link = 'Title', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfBorder', { link = 'FloatBorder', default = true })

  -- Input field highlights
  vim.api.nvim_set_hl(0, 'WherewolfInputLabel', { link = 'Label', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfInputField', { link = 'Normal', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfInputActive', { link = 'CursorLine', default = true })

  -- Results display highlights
  vim.api.nvim_set_hl(0, 'WherewolfMatchFile', { link = 'Directory', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfMatchLine', { link = 'LineNr', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfMatchText', { link = 'Search', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfMatchCount', { link = 'Number', default = true })

  -- Diff-style highlights (ast-grep style)
  vim.api.nvim_set_hl(0, 'WherewolfDiffAdd', { link = 'DiffAdd', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfDiffDelete', { link = 'DiffDelete', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfDiffAddSign', { fg = '#2ea043', bold = true, default = true })
  vim.api.nvim_set_hl(0, 'WherewolfDiffDeleteSign', { fg = '#f85149', bold = true, default = true })

  -- Separator and UI elements
  vim.api.nvim_set_hl(0, 'WherewolfSeparator', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfInfo', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfWarning', { link = 'WarningMsg', default = true })
  vim.api.nvim_set_hl(0, 'WherewolfError', { link = 'ErrorMsg', default = true })

  -- File tree/grouping highlights
  vim.api.nvim_set_hl(0, 'WherewolfFileHeader', { link = 'Directory', bold = true, default = true })
  vim.api.nvim_set_hl(0, 'WherewolfFoldedFile', { link = 'Folded', default = true })
end

---Get namespace ID for extmarks
---@return number namespace_id
function M.get_namespace()
  return vim.api.nvim_create_namespace('wherewolf')
end

return M
