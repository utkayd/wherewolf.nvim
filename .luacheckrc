-- Luacheck configuration for wherewolf.nvim

-- Global vim object
globals = {
  "vim",
}

-- Read globals (can be read but not set)
read_globals = {
  "vim",
}

-- Ignore warnings about line length
max_line_length = false

-- Ignore unused self warnings
self = false

-- Files and directories to exclude
exclude_files = {
  ".luarocks",
  ".test",
}

-- Ignore specific warnings
ignore = {
  "212", -- Unused argument
  "213", -- Unused loop variable
}
