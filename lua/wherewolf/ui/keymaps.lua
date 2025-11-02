-- Buffer-local keymaps for wherewolf.nvim

local inputs = require("wherewolf.ui.inputs")
local sidebar = require("wherewolf.ui.sidebar")

local M = {}

---Setup buffer-local keymaps
---@param buf number Buffer handle
function M.setup(buf)
  local opts = { buffer = buf, noremap = true, silent = true }

  -- Tab navigation between input fields
  vim.keymap.set({ 'n', 'i' }, '<Tab>', function()
    inputs.next_field(buf)
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Next input field' }))

  vim.keymap.set({ 'n', 'i' }, '<S-Tab>', function()
    inputs.prev_field(buf)
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Previous input field' }))

  -- j/k navigation in normal mode jumps between input fields
  vim.keymap.set('n', 'j', function()
    inputs.next_field(buf)
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Next input field' }))

  vim.keymap.set('n', 'k', function()
    inputs.prev_field(buf)
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Previous input field' }))

  -- Close sidebar
  vim.keymap.set('n', 'q', function()
    sidebar.close()
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Close sidebar' }))

  vim.keymap.set('n', '<Esc>', function()
    sidebar.close()
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Close sidebar' }))

  -- Jump to result under cursor
  vim.keymap.set('n', '<CR>', function()
    M.goto_result()
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Go to result' }))

  -- Apply single replacement
  vim.keymap.set('n', 'r', function()
    M.apply_single_replacement()
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Apply replacement' }))

  -- Apply all replacements
  vim.keymap.set('n', 'R', function()
    M.apply_all_replacements()
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Apply all replacements' }))

  -- Clear all inputs
  vim.keymap.set('n', '<C-c>', function()
    inputs.clear_all(buf)
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Clear inputs' }))

  -- Toggle advanced fields (include/exclude)
  vim.keymap.set('n', 'a', function()
    M.toggle_advanced()
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Toggle advanced fields' }))

  -- Refresh search
  vim.keymap.set('n', '<C-r>', function()
    require("wherewolf.ui").perform_search()
  end, vim.tbl_extend('force', opts, { desc = 'Wherewolf: Refresh search' }))
end

---Go to the result under cursor
function M.goto_result()
  local line = vim.api.nvim_get_current_line()

  -- Parse result line format: "    1234: - text" or "    1234: + text"
  local line_num_str = line:match("^%s*(%d+):")
  if not line_num_str then
    vim.notify("Not on a result line", vim.log.levels.WARN)
    return
  end

  local line_num = tonumber(line_num_str)
  if not line_num then
    return
  end

  -- Find which file this result belongs to
  local current_line_idx = vim.fn.line('.')
  local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Search backwards for file header (line with ▼)
  local filename = nil
  for i = current_line_idx, 1, -1 do
    local check_line = buf_lines[i]
    if check_line and check_line:match("^%s*▼") then
      -- Extract filename from: "  ▼ path/to/file.lua (5)"
      filename = check_line:match("^%s*▼%s*(.-)%s*%(")
      break
    end
  end

  if not filename then
    vim.notify("Could not determine file for this result", vim.log.levels.WARN)
    return
  end

  -- Open file
  sidebar.close()

  vim.schedule(function()
    vim.cmd('edit ' .. vim.fn.fnameescape(filename))
    vim.api.nvim_win_set_cursor(0, { line_num, 0 })
    vim.cmd('normal! zz') -- Center line in window
  end)
end

---Apply single replacement at cursor
function M.apply_single_replacement()
  vim.notify("Apply single replacement - Not yet implemented", vim.log.levels.INFO)
  -- TODO: Implement single replacement logic
end

---Apply all replacements
function M.apply_all_replacements()
  local state = require("wherewolf.ui.state")
  local search = require("wherewolf.search")
  local inputs = state.get_inputs()

  if inputs.search == "" then
    vim.notify("No search pattern specified", vim.log.levels.WARN)
    return
  end

  if inputs.replace == "" then
    vim.notify("No replacement text specified", vim.log.levels.WARN)
    return
  end

  local results = state.get_results()
  if #results == 0 then
    vim.notify("No results to replace", vim.log.levels.WARN)
    return
  end

  -- Count unique files
  local files = {}
  for _, result in ipairs(results) do
    files[result.filename] = true
  end
  local file_count = vim.tbl_count(files)

  -- Confirm before applying
  local response = vim.fn.input(string.format(
    "Apply %d replacements in %d files? (y/n): ",
    #results,
    file_count
  ))

  if response:lower() ~= 'y' then
    vim.notify("Replacement cancelled", vim.log.levels.INFO)
    return
  end

  -- Perform replacements
  local count = search.replace(inputs.search, inputs.replace, results)

  if count > 0 then
    vim.notify(
      string.format("Applied %d replacements in %d files", count, file_count),
      vim.log.levels.INFO
    )

    -- Refresh search to show updated results
    vim.schedule(function()
      require("wherewolf.ui").perform_search()
    end)
  else
    vim.notify("No replacements applied", vim.log.levels.WARN)
  end
end

---Toggle advanced input fields
function M.toggle_advanced()
  local state = require("wherewolf.ui.state")
  local sidebar = require("wherewolf.ui.sidebar")

  state.current.show_advanced = not state.current.show_advanced

  -- Refresh the sidebar content
  if state.is_buf_valid() then
    sidebar.refresh_content(state.current.buf)
  end

  vim.notify(
    "Advanced fields " .. (state.current.show_advanced and "shown" or "hidden"),
    vim.log.levels.INFO
  )
end

return M
