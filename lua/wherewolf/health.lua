-- Health check for wherewolf.nvim

local M = {}

---Perform health checks
function M.check()
  vim.health.start("wherewolf.nvim")

  -- Check Neovim version
  if vim.fn.has('nvim-0.9') == 1 then
    vim.health.ok("Neovim version is 0.9+")
  else
    vim.health.error("Neovim 0.9+ required", {
      "Upgrade Neovim to version 0.9 or higher",
      "Download from https://github.com/neovim/neovim/releases"
    })
  end

  -- Check for ripgrep
  if vim.fn.executable('rg') == 1 then
    local handle = io.popen('rg --version 2>&1')
    if handle then
      local result = handle:read("*a")
      handle:close()
      local version = result:match('ripgrep (%S+)')
      if version then
        vim.health.ok("ripgrep " .. version .. " found")
      else
        vim.health.ok("ripgrep found (version unknown)")
      end
    else
      vim.health.ok("ripgrep found")
    end
  else
    vim.health.error("ripgrep not found", {
      "Install ripgrep: https://github.com/BurntSushi/ripgrep",
      "macOS: brew install ripgrep",
      "Ubuntu: apt install ripgrep",
      "Windows: choco install ripgrep or scoop install ripgrep"
    })
  end

  -- Check for nui.nvim
  local ok, _ = pcall(require, 'nui.split')
  if ok then
    vim.health.ok("nui.nvim is installed")
  else
    vim.health.error("nui.nvim not found", {
      "Install nui.nvim: https://github.com/MunifTanjim/nui.nvim",
      "lazy.nvim: { 'MunifTanjim/nui.nvim' }",
      "LuaRocks: luarocks install nui.nvim"
    })
  end

  -- Check configuration
  local config_ok, config = pcall(require, 'wherewolf.config')
  if config_ok then
    local opts = config.get()

    if opts.max_results > 10000 then
      vim.health.warn(
        "max_results is very high (" .. opts.max_results .. ")",
        {"Consider lowering max_results for better performance"}
      )
    else
      vim.health.ok("Configuration looks good")
    end

    vim.health.info("Search engine: " .. opts.search_engine)
    vim.health.info("Sidebar position: " .. opts.ui.position)
    vim.health.info("Case sensitive: " .. tostring(opts.case_sensitive))
    vim.health.info("Debounce delay: " .. opts.debounce_ms .. "ms")
  else
    vim.health.warn("Could not load configuration")
  end
end

return M
