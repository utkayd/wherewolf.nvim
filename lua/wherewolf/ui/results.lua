-- Results display for wherewolf.nvim

local state = require("wherewolf.ui.state")
local highlights = require("wherewolf.ui.highlights")
local boundaries = require("wherewolf.ui.boundaries")

local M = {}

---Get namespace for extmarks
---@return number
local function get_ns()
  return highlights.get_namespace()
end

---Group results by file
---@param results table[] Search results
---@return table grouped {filename: {results}}
local function group_by_file(results)
  local grouped = {}

  for _, result in ipairs(results) do
    local file = result.filename
    if not grouped[file] then
      grouped[file] = {}
    end
    table.insert(grouped[file], result)
  end

  return grouped
end

---Format a single result line with diff markers
---@param result table Search result
---@param pattern string Search pattern
---@param replacement string Replacement text
---@return string delete_line Line with - marker
---@return string add_line Line with + marker
local function format_diff_lines(result, pattern, replacement)
  local line_num_str = string.format("%4d", result.lnum)

  -- Line to be deleted (red)
  local delete_line = string.format("    %s: - %s", line_num_str, result.text)

  -- Line to be added (green)
  local add_line
  if replacement and replacement ~= "" and pattern and pattern ~= "" then
    -- Replace pattern in text (preview only - actual replacement happens via search.replace)
    local new_text = result.text:gsub(vim.pesc(pattern), replacement)
    add_line = string.format("    %s: + %s", line_num_str, new_text)
  else
    -- No replacement specified - just show same text with + marker
    add_line = string.format("    %s:   %s", line_num_str, result.text)
  end

  return delete_line, add_line
end

---Display results in buffer
---@param buf number Buffer handle
---@param results table[] Search results
function M.display(buf, results)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local inputs = state.get_inputs()
  local pattern = inputs.search
  local replacement = inputs.replace

  -- Get results start position from extmark
  local results_start_row = boundaries.get_results_start_row(buf)

  -- Start building result lines
  local result_lines = {}

  if #results == 0 then
    table.insert(result_lines, "")
    table.insert(result_lines, "  No matches found.")
    table.insert(result_lines, "")
  else
    -- Group results by file
    local grouped = group_by_file(results)

    -- Count total matches
    local total_matches = #results
    local total_files = vim.tbl_count(grouped)

    -- Header
    table.insert(result_lines, "")
    table.insert(result_lines, string.format("  Found %d matches in %d files", total_matches, total_files))
    table.insert(result_lines, "")

    -- Display each file's results
    for filename, file_results in pairs(grouped) do
      -- File header
      local file_header = string.format("  ▼ %s (%d)", filename, #file_results)
      table.insert(result_lines, file_header)

      -- Results for this file
      for _, result in ipairs(file_results) do
        local delete_line, add_line = format_diff_lines(result, pattern, replacement)
        table.insert(result_lines, delete_line)
        table.insert(result_lines, add_line)
      end

      table.insert(result_lines, "")
    end
  end

  -- Use safe buffer modification (sets update_disabled flag)
  boundaries.set_buf_lines_safe(buf, results_start_row, -1, result_lines)

  -- Apply syntax highlighting with extmarks
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      M.apply_highlights(buf, results_start_row + 1)
    end
  end)
end

---Apply syntax highlighting to results
---@param buf number Buffer handle
---@param start_line number Line number where results start (1-indexed)
function M.apply_highlights(buf, start_line)
  local ns = get_ns()

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  -- Get all lines
  local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, -1, false)

  for i, line in ipairs(lines) do
    local line_num = start_line - 1 + i - 1 -- Convert to 0-indexed

    -- Highlight file headers (lines starting with ▼)
    if line:match("^%s*▼") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_num, 0, {
        end_col = #line,
        hl_group = 'WherewolfFileHeader',
      })
    end

    -- Highlight delete lines (with -)
    if line:match(":%s*%-") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_num, 0, {
        end_col = #line,
        hl_group = 'WherewolfDiffDelete',
      })

      -- Highlight the - sign specifically
      local minus_pos = line:find("%-")
      if minus_pos then
        vim.api.nvim_buf_set_extmark(buf, ns, line_num, minus_pos - 1, {
          end_col = minus_pos,
          hl_group = 'WherewolfDiffDeleteSign',
        })
      end
    end

    -- Highlight add lines (with +)
    if line:match(":%s*%+") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_num, 0, {
        end_col = #line,
        hl_group = 'WherewolfDiffAdd',
      })

      -- Highlight the + sign specifically
      local plus_pos = line:find("%+")
      if plus_pos then
        vim.api.nvim_buf_set_extmark(buf, ns, line_num, plus_pos - 1, {
          end_col = plus_pos,
          hl_group = 'WherewolfDiffAddSign',
        })
      end
    end

    -- Highlight line numbers
    local line_num_match = line:match("^%s*(%d+):")
    if line_num_match then
      local line_num_start = line:find(line_num_match)
      if line_num_start then
        vim.api.nvim_buf_set_extmark(buf, ns, line_num, line_num_start - 1, {
          end_col = line_num_start - 1 + #line_num_match,
          hl_group = 'WherewolfMatchLine',
        })
      end
    end

    -- Highlight "Found X matches in Y files"
    if line:match("Found %d+ matches") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_num, 0, {
        end_col = #line,
        hl_group = 'WherewolfInfo',
      })
    end
  end
end

---Clear results display
---@param buf number Buffer handle
function M.clear(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Get results start position from extmark
  local results_start_row = boundaries.get_results_start_row(buf)

  -- Add empty state message
  local result_lines = {
    "",
    "  No results yet. Start typing to search...",
    "",
  }

  -- Use safe buffer modification
  boundaries.set_buf_lines_safe(buf, results_start_row, -1, result_lines)

  -- Clear highlights
  vim.api.nvim_buf_clear_namespace(buf, boundaries.ns_results, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, boundaries.ns_hl, 0, -1)
end

---Show loading indicator
---@param buf number Buffer handle
function M.show_loading(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Get results start position from extmark
  local results_start_row = boundaries.get_results_start_row(buf)

  local result_lines = {
    "",
    "  Searching...",
    "",
  }

  -- Use safe buffer modification
  boundaries.set_buf_lines_safe(buf, results_start_row, -1, result_lines)
end

return M
