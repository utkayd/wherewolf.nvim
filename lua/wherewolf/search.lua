-- Search logic using ripgrep for wherewolf.nvim

local M = {}

---Blacklisted ripgrep flags that break parsing or cause issues
local BLACKLISTED_FLAGS = {
  '--binary',
  '--json',
  '--null-data',
  '--null',
  '-0',
  '--files',
  '--files-with-matches',
  '--files-without-match',
  '-l',
  '-L',
}

---@class WherewolfSearchResult
---@field filename string Path to file
---@field lnum number Line number
---@field col number Column number
---@field text string Matched line text
---@field match? string The actual matched text

---Validate user-provided ripgrep flags
---@param flags string[] List of flags to validate
---@return boolean valid Whether flags are valid
---@return string? error Error message if invalid
function M.validate_flags(flags)
  for _, flag in ipairs(flags) do
    for _, blacklisted in ipairs(BLACKLISTED_FLAGS) do
      if flag == blacklisted or flag:match("^" .. vim.pesc(blacklisted) .. "=") then
        local msg = "Blacklisted ripgrep flag: " .. flag
        return false, msg
      end
    end
  end
  return true
end

---Parse ripgrep --vimgrep output line
---@param line string Line in format "file:line:col:text"
---@return WherewolfSearchResult?
function M.parse_vimgrep_line(line)
  if line == "" then
    return nil
  end

  -- Format: "file:line:col:text"
  -- Handle filenames that might contain colons (e.g., Windows paths)
  local parts = {}
  for part in line:gmatch("[^:]+") do
    table.insert(parts, part)
  end

  if #parts < 4 then
    return nil
  end

  -- The last 3 parts before text are col, line, and the last part of filename
  local text_parts = {}
  for i = 4, #parts do
    table.insert(text_parts, parts[i])
  end
  local text = table.concat(text_parts, ":")

  local lnum = tonumber(parts[#parts - 2])
  local col = tonumber(parts[#parts - 1])

  if not lnum or not col then
    return nil
  end

  -- Reconstruct filename (everything before line:col)
  local filename_parts = {}
  for i = 1, #parts - 3 do
    table.insert(filename_parts, parts[i])
  end
  local filename = table.concat(filename_parts, ":")

  return {
    filename = filename,
    lnum = lnum,
    col = col,
    text = text,
  }
end

---Execute a search using ripgrep
---@param pattern string Search pattern
---@param opts? table Options
---@return number job_id Job ID or -1 on failure
function M.execute(pattern, opts)
  print("[wherewolf] search.execute() called with pattern:", pattern)

  opts = opts or {}
  local config = require("wherewolf.config").get()

  if not pattern or pattern == "" then
    print("[wherewolf] Empty pattern, aborting")
    if opts.on_error then
      opts.on_error("Empty search pattern")
    end
    return -1
  end

  -- Check if ripgrep is available
  if vim.fn.executable('rg') == 0 then
    local msg = "ripgrep not found. Please install ripgrep."
    print("[wherewolf]", msg)
    vim.notify(msg, vim.log.levels.ERROR)
    if opts.on_error then
      opts.on_error(msg)
    end
    return -1
  end

  -- Build ripgrep command
  local cmd = { 'rg', '--vimgrep', '--no-heading', '--color=never' }

  -- Add case sensitivity flag
  if not (opts.case_sensitive or config.case_sensitive) then
    table.insert(cmd, '--smart-case')
  else
    table.insert(cmd, '--case-sensitive')
  end

  -- Add multiline flag
  if opts.multiline or config.multiline then
    table.insert(cmd, '--multiline')
  end

  -- Add max count
  if opts.max_count or config.max_results then
    table.insert(cmd, '--max-count=' .. (opts.max_count or config.max_results))
  end

  -- Add gitignore flag
  if config.rg.respect_gitignore == false then
    table.insert(cmd, '--no-ignore')
  end

  -- Add hidden files flag
  if config.rg.hidden then
    table.insert(cmd, '--hidden')
  end

  -- Add extra args from config
  if config.rg.extra_args and #config.rg.extra_args > 0 then
    local valid, err = M.validate_flags(config.rg.extra_args)
    if valid then
      vim.list_extend(cmd, config.rg.extra_args)
    else
      vim.notify("Invalid ripgrep flag in config: " .. (err or ""), vim.log.levels.WARN)
    end
  end

  -- Add user-provided flags
  if opts.rg_flags and #opts.rg_flags > 0 then
    local valid, err = M.validate_flags(opts.rg_flags)
    if valid then
      vim.list_extend(cmd, opts.rg_flags)
    else
      vim.notify(err or "Invalid ripgrep flags", vim.log.levels.ERROR)
      if opts.on_error then
        opts.on_error(err or "Invalid flags")
      end
      return -1
    end
  end

  -- Add file filters
  if opts.include and opts.include ~= "" then
    for glob in opts.include:gmatch("[^%s]+") do
      table.insert(cmd, '--glob=' .. glob)
    end
  end

  if opts.exclude and opts.exclude ~= "" then
    for glob in opts.exclude:gmatch("[^%s]+") do
      table.insert(cmd, '--glob=!' .. glob)
    end
  end

  -- Add pattern
  table.insert(cmd, '--')
  table.insert(cmd, pattern)

  -- Add path (default to current directory)
  if opts.path then
    table.insert(cmd, opts.path)
  end

  -- Execute asynchronously
  local results = {}
  local stderr_output = {}

  print("[wherewolf] Starting ripgrep with command:", vim.inspect(cmd))

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      print("[wherewolf] on_stdout callback, lines:", #data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            local parsed = M.parse_vimgrep_line(line)
            if parsed then
              table.insert(results, parsed)
            end
          end
        end
      end
    end,
    on_stderr = function(_, data)
      print("[wherewolf] on_stderr callback")
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_output, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      print("[wherewolf] on_exit callback, exit_code:", exit_code, "results:", #results)

      -- Exit codes:
      -- 0 = success with matches
      -- 1 = success without matches
      -- 143 = SIGTERM (job was cancelled) - this is NORMAL
      -- 15 = job stopped
      if exit_code == 0 or exit_code == 1 then
        -- Normal completion
        if opts.on_complete then
          print("[wherewolf] Calling on_complete with", #results, "results")
          opts.on_complete(results)
        else
          print("[wherewolf] WARNING: on_complete callback is nil!")
        end
      elseif exit_code == 143 or exit_code == 15 or exit_code == 130 then
        -- Job was cancelled (SIGTERM/SIGINT) - this is NORMAL, not an error
        print("[wherewolf] Job was cancelled (exit code " .. exit_code .. "), ignoring")
        -- Don't call on_error or on_complete - just silently ignore cancelled jobs
      else
        -- Actual error
        local error_msg = table.concat(stderr_output, "\n")
        print("[wherewolf] Error exit code, message:", error_msg)
        if error_msg ~= "" then
          vim.notify('ripgrep error: ' .. error_msg, vim.log.levels.ERROR)
        end
        if opts.on_error then
          opts.on_error(error_msg)
        end
      end
    end,
  })

  print("[wherewolf] Job started with ID:", job_id)

  if job_id <= 0 then
    local msg = "Failed to start ripgrep"
    print("[wherewolf] FAILED TO START JOB")
    vim.notify(msg, vim.log.levels.ERROR)
    if opts.on_error then
      opts.on_error(msg)
    end
  end

  return job_id
end

---Perform replacement in files
---@param pattern string Search pattern
---@param replacement string Replacement text
---@param results WherewolfSearchResult[] Search results to replace
---@return number count Number of replacements made
function M.replace(pattern, replacement, results)
  if not results or #results == 0 then
    return 0
  end

  -- Group by file
  local files = {}
  for _, result in ipairs(results) do
    if not files[result.filename] then
      files[result.filename] = {}
    end
    table.insert(files[result.filename], result)
  end

  local total_replaced = 0

  -- Process each file
  for filename, file_results in pairs(files) do
    -- Read file
    local file = io.open(filename, "r")
    if not file then
      vim.notify("Could not open file: " .. filename, vim.log.levels.ERROR)
      goto continue
    end

    local content = file:read("*all")
    file:close()

    -- Perform replacements
    local new_content = content:gsub(pattern, replacement)

    -- Write back if changed
    if new_content ~= content then
      file = io.open(filename, "w")
      if file then
        file:write(new_content)
        file:close()
        total_replaced = total_replaced + #file_results
      else
        vim.notify("Could not write file: " .. filename, vim.log.levels.ERROR)
      end
    end

    ::continue::
  end

  return total_replaced
end

return M
