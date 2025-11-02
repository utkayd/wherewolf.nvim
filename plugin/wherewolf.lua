-- Plugin initialization for wherewolf.nvim
-- This file loads automatically when Neovim starts

-- Prevent duplicate loading
if vim.g.loaded_wherewolf then
  return
end
vim.g.loaded_wherewolf = 1

-- Check Neovim version
if vim.fn.has('nvim-0.9') == 0 then
  vim.notify('wherewolf.nvim requires Neovim 0.9+', vim.log.levels.ERROR)
  return
end

-- Check for nui.nvim dependency
local has_nui, _ = pcall(require, 'nui.split')
if not has_nui then
  vim.notify(
    'wherewolf.nvim requires nui.nvim. Install it with your plugin manager.',
    vim.log.levels.ERROR
  )
  return
end

-- Define user commands
vim.api.nvim_create_user_command('Wherewolf', function(opts)
  -- Lazy load on command execution
  require('wherewolf').handle_command(opts)
end, {
  nargs = '+',
  desc = 'Wherewolf find and replace',
  complete = function(arg_lead, cmdline, cursor_pos)
    local subcmds = { 'toggle', 'open', 'close', 'search', 'replace' }
    return vim.tbl_filter(function(cmd)
      return cmd:find(arg_lead) == 1
    end, subcmds)
  end,
})

-- Define <Plug> mappings for users to map
vim.keymap.set('n', '<Plug>(WherewolfToggle)', function()
  require('wherewolf').toggle()
end, { desc = 'Wherewolf: Toggle sidebar' })

vim.keymap.set('n', '<Plug>(WherewolfOpen)', function()
  require('wherewolf').open()
end, { desc = 'Wherewolf: Open sidebar' })

vim.keymap.set('n', '<Plug>(WherewolfClose)', function()
  require('wherewolf').close()
end, { desc = 'Wherewolf: Close sidebar' })

vim.keymap.set('n', '<Plug>(WherewolfSearch)', function()
  require('wherewolf').search('')
end, { desc = 'Wherewolf: Start search' })

vim.keymap.set('n', '<Plug>(WherewolfSearchWord)', function()
  require('wherewolf').search_word()
end, { desc = 'Wherewolf: Search word under cursor' })

vim.keymap.set('v', '<Plug>(WherewolfSearchVisual)', function()
  require('wherewolf').search_visual()
end, { desc = 'Wherewolf: Search visual selection' })

vim.keymap.set('n', '<Plug>(WherewolfReplace)', function()
  require('wherewolf').apply_replacements()
end, { desc = 'Wherewolf: Apply replacements' })
