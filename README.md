# 🐺 wherewolf.nvim

A blazing-fast, VSCode-like find and replace plugin for Neovim, powered by [ripgrep](https://github.com/BurntSushi/ripgrep).

![Neovim](https://img.shields.io/badge/Neovim-0.9+-green.svg?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)

## ✨ Features

- 🚀 **Blazing Fast**: Powered by ripgrep for lightning-fast project-wide search
- 🎨 **VSCode-like UI**: Familiar vertical sidebar interface with toggle support
- ⌨️ **Interactive Input Fields**: Tab navigation between search, replace, include, and exclude fields
- 🔴🟢 **Visual Diff Preview**: ast-grep style diff display with `-` (red) and `+` (green) markers
- ⚡ **Live Updates**: Debounced search as you type (configurable delay)
- 🎯 **Smart Navigation**: Jump directly to results with `<CR>`
- 🔧 **Highly Configurable**: Extensive configuration options for UI and search behavior
- 📦 **Zero Config Required**: Works out of the box with sensible defaults
- 🔍 **Full Regex Support**: Leverage ripgrep's powerful regex engine
- 🎭 **Multiple Search Modes**: Search word under cursor, visual selection, or custom patterns

## 📸 Demo

> 🚧 Demo GIF coming soon

## 📋 Requirements

- **Neovim 0.9+**
- **ripgrep** - [Installation Guide](https://github.com/BurntSushi/ripgrep#installation)
- **nui.nvim** - Automatically installed as a dependency

### Installing ripgrep

```bash
# macOS
brew install ripgrep

# Ubuntu/Debian
apt install ripgrep

# Arch Linux
pacman -S ripgrep

# Windows (Chocolatey)
choco install ripgrep

# Windows (Scoop)
scoop install ripgrep
```

## 📦 Installation

### lazy.nvim (Recommended)

```lua
{
  'utkayd/wherewolf.nvim',
  dependencies = {
    'MunifTanjim/nui.nvim',  -- Required dependency
  },
  cmd = 'Wherewolf',  -- Lazy load on command
  keys = {
    { '<leader>fw', '<Plug>(WherewolfSearch)', desc = 'Wherewolf: Search' },
    { '<leader>fr', '<Plug>(WherewolfToggle)', desc = 'Wherewolf: Toggle' },
    { '<leader>fW', '<Plug>(WherewolfSearchWord)', desc = 'Wherewolf: Search word' },
    { '<leader>fw', '<Plug>(WherewolfSearchVisual)', mode = 'v', desc = 'Wherewolf: Search selection' },
  },
  opts = {
    ui = {
      position = "right",  -- or "left"
      width = 50,          -- or "30%"
    },
  },
}
```

### packer.nvim

```lua
use {
  'utkayd/wherewolf.nvim',
  requires = { 'MunifTanjim/nui.nvim' },
  config = function()
    require('wherewolf').setup()
  end
}
```

### vim-plug

```vim
Plug 'MunifTanjim/nui.nvim'
Plug 'utkayd/wherewolf.nvim'
```

For more installation options, see [INSTALL.md](INSTALL.md).

## 🚀 Quick Start

1. **Open the sidebar**:
   ```vim
   :Wherewolf toggle
   ```

2. **Type your search pattern** in the Pattern field

3. **Use Tab/Shift-Tab** to navigate between fields

4. **Press Enter** on a result to jump to it

5. **Type replacement text** and press `R` to apply all replacements

## 📖 Usage

### Commands

```vim
:Wherewolf toggle                      " Toggle sidebar
:Wherewolf open                        " Open sidebar
:Wherewolf close                       " Close sidebar
:Wherewolf search <pattern>            " Search for pattern
:Wherewolf replace <pattern> <text>    " Search and set replacement
```

### Keymaps

wherewolf.nvim provides `<Plug>` mappings that you can map to your preferred keys:

```lua
-- Recommended mappings
vim.keymap.set('n', '<leader>fw', '<Plug>(WherewolfSearch)')
vim.keymap.set('n', '<leader>fr', '<Plug>(WherewolfToggle)')
vim.keymap.set('n', '<leader>fW', '<Plug>(WherewolfSearchWord)')
vim.keymap.set('v', '<leader>fw', '<Plug>(WherewolfSearchVisual)')
```

**Available `<Plug>` mappings**:
- `<Plug>(WherewolfToggle)` - Toggle sidebar
- `<Plug>(WherewolfOpen)` - Open sidebar
- `<Plug>(WherewolfClose)` - Close sidebar
- `<Plug>(WherewolfSearch)` - Start search
- `<Plug>(WherewolfSearchWord)` - Search word under cursor
- `<Plug>(WherewolfSearchVisual)` - Search visual selection
- `<Plug>(WherewolfReplace)` - Apply replacements

### Buffer-local Keymaps (Inside Sidebar)

When the wherewolf sidebar is focused, these keymaps are available:

| Key | Action |
|-----|--------|
| `<Tab>` | Next input field |
| `<S-Tab>` | Previous input field |
| `<CR>` | Jump to result under cursor |
| `q` / `<Esc>` | Close sidebar |
| `R` | Apply all replacements |
| `<C-c>` | Clear all input fields |
| `<C-r>` | Refresh search |
| `a` | Toggle advanced fields (include/exclude) |

## ⚙️ Configuration

### Default Configuration

```lua
require('wherewolf').setup({
  search_engine = "ripgrep",
  case_sensitive = false,
  multiline = false,
  max_results = 1000,
  debounce_ms = 150,

  ui = {
    position = "right",              -- "left" or "right"
    width = 50,                      -- number or percentage string "30%"
    show_include_exclude = false,    -- Show advanced fields by default
    auto_focus = true,               -- Auto focus when opening
  },

  rg = {
    extra_args = {},                 -- Additional ripgrep arguments
    respect_gitignore = true,        -- Respect .gitignore files
    hidden = false,                  -- Search hidden files
  },
})
```

### Configuration Options

#### General Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `search_engine` | string | `"ripgrep"` | Search engine (currently only ripgrep supported) |
| `case_sensitive` | boolean | `false` | Use case-sensitive search |
| `multiline` | boolean | `false` | Enable multiline pattern matching |
| `max_results` | number | `1000` | Maximum number of results to display |
| `debounce_ms` | number | `150` | Debounce delay for live search (milliseconds) |

#### UI Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ui.position` | string | `"right"` | Sidebar position: `"left"` or `"right"` |
| `ui.width` | number/string | `50` | Width in columns or percentage (e.g., `"30%"`) |
| `ui.show_include_exclude` | boolean | `false` | Show include/exclude fields by default |
| `ui.auto_focus` | boolean | `true` | Auto focus sidebar when opening |

#### Ripgrep Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `rg.extra_args` | table | `{}` | Additional ripgrep command-line arguments |
| `rg.respect_gitignore` | boolean | `true` | Respect `.gitignore` files |
| `rg.hidden` | boolean | `false` | Search hidden files and directories |

### Example Configurations

#### Left-side Sidebar with Larger Width

```lua
require('wherewolf').setup({
  ui = {
    position = "left",
    width = "40%",
  },
})
```

#### Search Hidden Files and Respect No Ignore Files

```lua
require('wherewolf').setup({
  rg = {
    hidden = true,
    respect_gitignore = false,
    extra_args = { '--no-ignore' },
  },
})
```

#### Faster Debounce for Instant Results

```lua
require('wherewolf').setup({
  debounce_ms = 50,  -- Update results after 50ms
  max_results = 500,  -- Limit results for better performance
})
```

## 🔍 How It Works

### Search Process

1. **Input Detection**: As you type in the Pattern field, changes are detected via `TextChanged` autocmd
2. **Debouncing**: Changes are debounced (default 150ms) to avoid excessive searches
3. **Ripgrep Execution**: ripgrep is executed asynchronously via `vim.fn.jobstart()`
4. **Output Parsing**: Results are parsed from ripgrep's `--vimgrep` format
5. **UI Update**: Results are displayed with syntax highlighting and diff markers
6. **State Management**: All state is tracked for restoration and navigation

### Replace Process

1. **Pattern Matching**: Uses the search pattern you've defined
2. **File Grouping**: Results are grouped by file for efficient processing
3. **Content Replacement**: Files are read, pattern is replaced using Lua's `string.gsub()`
4. **File Writing**: Modified content is written back to disk
5. **Refresh**: Search is automatically refreshed to show updated results

### Technical Details

- **Async Operations**: All I/O operations are non-blocking
- **Extmarks**: Virtual text and highlights are implemented using Neovim's extmark API
- **Buffer Management**: Custom buffer with `buftype=nofile` for the UI
- **State Persistence**: UI state is preserved across toggles
- **Flag Validation**: Dangerous ripgrep flags are blacklisted for safety

### Ripgrep Flags

wherewolf.nvim uses the following ripgrep flags by default:

```bash
rg --vimgrep --no-heading --color=never --smart-case
```

Additional flags based on configuration:
- `--smart-case` (when not case_sensitive)
- `--case-sensitive` (when case_sensitive = true)
- `--multiline` (when multiline = true)
- `--max-count=N` (based on max_results)
- `--no-ignore` (when respect_gitignore = false)
- `--hidden` (when hidden = true)

### Blacklisted Flags

For safety and compatibility, these ripgrep flags are blacklisted:
- `--binary`, `--json`, `--null-data`, `--null`, `-0`
- `--files`, `--files-with-matches`, `--files-without-match`, `-l`, `-L`

These flags would break the output parsing or change behavior unexpectedly.

## 🎯 Use Cases

### Find All TODOs in Your Project

1. Open wherewolf: `:Wherewolf toggle`
2. Type: `TODO` in Pattern field
3. Navigate results with `j`/`k`, jump with `<CR>`

### Rename a Function Across Multiple Files

1. Open wherewolf: `:Wherewolf toggle`
2. Pattern: `oldFunctionName`
3. Replace: `newFunctionName`
4. Review results (shows `-` old, `+` new)
5. Press `R` to apply all replacements

### Search Only in Specific File Types

1. Open wherewolf
2. Pattern: `your_pattern`
3. Press `a` to show advanced fields
4. Files: `*.lua *.vim`
5. Results update automatically

### Search with Regex

1. Open wherewolf
2. Pattern: `function\s+\w+\(` (finds function declarations)
3. View all matches across your project

### Exclude Certain Directories

1. Open wherewolf
2. Pattern: `search_term`
3. Press `a` for advanced fields
4. Exclude: `test/* spec/* node_modules/*`

## 🏥 Health Check

Run Neovim's health check to verify your installation:

```vim
:checkhealth wherewolf
```

This will check:
- ✅ Neovim version (0.9+)
- ✅ ripgrep installation
- ✅ nui.nvim dependency
- ✅ Configuration validity

## 🎨 Customization

### Custom Highlight Groups

You can customize the appearance by overriding these highlight groups:

```lua
vim.api.nvim_set_hl(0, 'WherewolfTitle', { fg = '#89b4fa', bold = true })
vim.api.nvim_set_hl(0, 'WherewolfInputLabel', { fg = '#f38ba8' })
vim.api.nvim_set_hl(0, 'WherewolfMatchFile', { fg = '#94e2d5' })
vim.api.nvim_set_hl(0, 'WherewolfDiffAdd', { bg = '#1e3a28', fg = '#a6e3a1' })
vim.api.nvim_set_hl(0, 'WherewolfDiffDelete', { bg = '#3c1f1e', fg = '#f38ba8' })
vim.api.nvim_set_hl(0, 'WherewolfDiffAddSign', { fg = '#a6e3a1', bold = true })
vim.api.nvim_set_hl(0, 'WherewolfDiffDeleteSign', { fg = '#f38ba8', bold = true })
```

**Available highlight groups**:
- `WherewolfTitle` - Sidebar title
- `WherewolfBorder` - Border elements
- `WherewolfInputLabel` - Input field labels
- `WherewolfInputField` - Input field content
- `WherewolfInputActive` - Active input field
- `WherewolfMatchFile` - File names in results
- `WherewolfMatchLine` - Line numbers
- `WherewolfMatchText` - Matched text
- `WherewolfDiffAdd` - Added lines (green background)
- `WherewolfDiffDelete` - Deleted lines (red background)
- `WherewolfDiffAddSign` - `+` sign
- `WherewolfDiffDeleteSign` - `-` sign
- `WherewolfSeparator` - UI separators
- `WherewolfInfo` - Info messages
- `WherewolfWarning` - Warning messages
- `WherewolfError` - Error messages

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development

1. Clone the repository
2. Make your changes
3. Test locally by adding to your Neovim config:
   ```lua
   {
     dir = '~/path/to/wherewolf.nvim',
     dependencies = { 'MunifTanjim/nui.nvim' },
     opts = {},
   }
   ```
4. Run health check: `:checkhealth wherewolf`
5. Submit a PR

## 🐛 Known Issues

- Replacement feature is currently basic and doesn't support regex capture groups (coming soon)
- Advanced fields (include/exclude) toggle is not yet fully implemented
- Single replacement (per result) is not yet implemented

## 📝 Roadmap

- [ ] Support for ast-grep as an alternative search engine
- [ ] Regex capture groups in replacements
- [ ] Per-result replacement (not just all)
- [ ] Search history
- [ ] Save/load search profiles
- [ ] Replace preview with undo capability
- [ ] Quickfix integration
- [ ] Telescope integration
- [ ] Help documentation (`:help wherewolf`)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

## 🙏 Acknowledgments

- [ripgrep](https://github.com/BurntSushi/ripgrep) - The amazing search tool that powers this plugin
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim) - UI component library
- [grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim) - Inspiration for find/replace UI
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Inspiration for ripgrep integration

## 📚 See Also

- [grug-far.nvim](https://github.com/MagicDuck/grug-far.nvim) - Find and replace with buffer-based UI
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Fuzzy finder with search capabilities
- [nvim-spectre](https://github.com/nvim-pack/nvim-spectre) - Search and replace panel

---

Made with ❤️ for the Neovim community
