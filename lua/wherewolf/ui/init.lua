-- UI orchestration for wherewolf.nvim

local sidebar = require("wherewolf.ui.sidebar")
local state = require("wherewolf.ui.state")
local results = require("wherewolf.ui.results")
local highlights = require("wherewolf.ui.highlights")
local search = require("wherewolf.search")

local M = {}

---Initialize UI system
function M.init()
  -- Setup highlight groups
  highlights.setup()
end

---Open wherewolf UI
function M.open()
  sidebar.open()
end

---Close wherewolf UI
function M.close()
  sidebar.close()
end

---Toggle wherewolf UI
function M.toggle()
  sidebar.toggle()
end

---Perform search with current inputs
function M.perform_search()

  if not state.is_buf_valid() then
    vim.notify("Wherewolf buffer is not valid", vim.log.levels.ERROR)
    return
  end

  -- CRITICAL: Cancel any running search job first!
  local search_module = require("wherewolf.search")
  if search_module._current_search_obj then
    pcall(function() search_module._current_search_obj:kill(15) end) -- SIGTERM
    search_module._current_search_obj = nil
    state.current.search_job_id = nil
    -- Reset the searching flag when we cancel
    state.current.is_searching = false
  end

  local buf = state.current.buf
  local inputs = state.get_inputs()

  -- Validate inputs
  if inputs.search == "" then
    results.clear(buf)
    return
  end

  -- Show loading indicator
  results.show_loading(buf)
  state.current.is_searching = true

  -- Build search options
  local search_opts = {
    case_sensitive = false,
    multiline = false,
    include = inputs.include ~= "" and inputs.include or nil,
    exclude = inputs.exclude ~= "" and inputs.exclude or nil,
    rg_flags = {},
    on_complete = function(search_results)

      -- Store results in state
      state.set_results(search_results)

      -- Display results
      if vim.api.nvim_buf_is_valid(buf) then
        results.display(buf, search_results)
      else
      end

      -- Notify user
      if #search_results == 0 then
        vim.notify("No matches found", vim.log.levels.INFO)
      else
        local file_count = M.count_files(search_results)
        vim.notify(
          string.format("Found %d matches in %d files", #search_results, file_count),
          vim.log.levels.INFO
        )
      end

      -- IMPORTANT: Reset searching flag LAST, after all UI updates
      state.current.is_searching = false
      state.current.search_job_id = nil
    end,
    on_error = function(error_msg)
      state.current.is_searching = false
      state.current.search_job_id = nil  -- Clear job_id on error

      -- Show error in results
      if vim.api.nvim_buf_is_valid(buf) then
        results.clear(buf)
      end

      vim.notify("Search error: " .. error_msg, vim.log.levels.ERROR)
    end,
  }

  -- Execute search and store job_id so we can cancel it later
  local job_id = search.execute(inputs.search, search_opts)
  state.current.search_job_id = job_id
end

---Count number of unique files in results
---@param search_results table[] Search results
---@return number count Number of unique files
function M.count_files(search_results)
  local files = {}
  for _, result in ipairs(search_results) do
    files[result.filename] = true
  end
  return vim.tbl_count(files)
end

---Apply replacements to all results
function M.apply_replacements()
  local inputs = state.get_inputs()
  local search_results = state.get_results()

  if inputs.search == "" then
    vim.notify("No search pattern specified", vim.log.levels.WARN)
    return
  end

  if inputs.replace == "" then
    vim.notify("No replacement text specified", vim.log.levels.WARN)
    return
  end

  if #search_results == 0 then
    vim.notify("No results to replace", vim.log.levels.WARN)
    return
  end

  -- Confirm before applying
  local file_count = M.count_files(search_results)
  local response = vim.fn.input(string.format(
    "Apply %d replacements in %d files? (y/n): ",
    #search_results,
    file_count
  ))

  if response:lower() ~= 'y' then
    vim.notify("Replacement cancelled", vim.log.levels.INFO)
    return
  end

  -- Perform replacement
  local count = search.replace(inputs.search, inputs.replace, search_results)

  if count > 0 then
    vim.notify(
      string.format("Applied %d replacements", count),
      vim.log.levels.INFO
    )

    -- Refresh search to show updated results
    vim.schedule(function()
      M.perform_search()
    end)
  else
    vim.notify("No replacements applied", vim.log.levels.WARN)
  end
end

---Focus input field
---@param field_num number Field number (1-4)
function M.focus_field(field_num)
  if not state.is_open() then
    M.open()
  end

  sidebar.focus()

  -- Move to field
  vim.schedule(function()
    if state.is_buf_valid() then
      require("wherewolf.ui.inputs").next_field(state.current.buf)
      -- Keep calling next_field until we reach the desired field
      for _ = 2, field_num do
        require("wherewolf.ui.inputs").next_field(state.current.buf)
      end
    end
  end)
end

---Set search pattern programmatically
---@param pattern string Search pattern
function M.set_search(pattern)
  if not state.is_open() then
    M.open()
  end

  state.update_input("search", pattern)

  -- Update buffer using safe wrapper (label is virtual text, so we just set the value)
  if state.is_buf_valid() then
    local buf = state.current.buf
    local line_num = state.input_lines.search

    state.current.update_disabled = true

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { pattern })

    vim.schedule(function()
      state.current.update_disabled = false
    end)

    -- Trigger search
    vim.schedule(function()
      M.perform_search()
    end)
  end
end

---Set replace text programmatically
---@param replacement string Replacement text
function M.set_replace(replacement)
  state.update_input("replace", replacement)

  -- Update buffer using safe wrapper (label is virtual text, so we just set the value)
  if state.is_buf_valid() then
    local buf = state.current.buf
    local line_num = state.input_lines.replace

    state.current.update_disabled = true

    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { replacement })

    vim.schedule(function()
      state.current.update_disabled = false
    end)
  end
end

return M
