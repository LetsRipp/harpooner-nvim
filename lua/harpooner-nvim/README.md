# Harpooner (harpooner-nvim)

[![License: Proprietary](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE.md) A Neovim plugin for bookmarking files and managing lists of bookmarks, inspired by ThePrimeagen's harpoon but built with Lua and offering distinct features for list management. Quickly jump between frequently used files and organize them into named lists for different projects or contexts.

## Features

* **File Bookmarking:** Easily add the current file to your bookmark list.
* **Quick Navigation:** Jump to bookmarked files using configurable index-based keymaps (e.g., `<leader>1`, `<leader>2`, ...).
* **Floating UI:** A clean floating window displays the current bookmark list.
* **List Management (UI):**
    * Open selected file (`<CR>`).
    * Delete bookmarks from the current list (`dd`).
    * Reorder bookmarks within the list (`J`/`K`).
* **Named Lists:**
    * Save your current set of bookmarks as a named list (e.g., "my-project", "dotfiles").
    * Load previously saved lists, replacing the current list.
    * Select which list to load via a UI prompt.
    * Delete unwanted saved lists via a command (with confirmation).
* **Persistence:** Remembers your last active bookmark list across Neovim sessions.
* **Configuration:** Customize keymaps, UI appearance (border, size), and behavior.

## Installation

Use your preferred plugin manager.

**lazy.nvim**
```lua
{
  'LetsRipp/harpooner.git',
  -- Optional: specify dependencies or configuration here
  config = function()
    require('harpooner-nvim').setup({
      -- Your custom configuration settings (see below)
    })
  end,
  -- Optional: If you want to lazy load, specify triggers like commands or keys
  -- cmd = { "HarpoonerList", "HarpoonerAdd", ... },
  -- keys = { "<leader>a", "<C-e>", ... },
}
```

**packer.nvim**
```lua
use {
  'LetsRipp/harpooner.git',
  config = function()
    require('harpooner-nvim').setup({
      -- Your custom configuration settings (see below)
    })
  end,
}
```

**vim-plug**
```vim
Plug 'LetsRipp/harpooner.git'

" Then somewhere in your init.lua or Lua config file:
lua << EOF
require('harpooner-nvim').setup({
  -- Your custom configuration settings (see below)
})
EOF
```

## Setup & Configuration

Harpooner comes with default settings, but you can override them by passing a table to the `setup()` function.

```lua
-- Place this in your Neovim Lua configuration (e.g., init.lua or a dedicated plugin config file)
require('harpooner-nvim').setup({
  -- Automatically save the current list state when Neovim exits
  save_on_exit = true,

  -- UI Customization (refer to ui.lua for all options)
  ui = {
    ui_width_ratio = 0.5,   -- Ratio of terminal width (default 0.5)
    ui_max_width = 100,     -- Max width in columns (default 100)
    height_in_lines = 12,   -- Height of the UI window (default 12)
    border = "rounded",     -- Border style: "none", "single", "double", "rounded", etc.
    -- title = "My Bookmarks", -- Optional: Custom title
    -- show_numbers = true,  -- Show line numbers in the UI (default true)
  },

  -- Keymap Customization (set to `false` or empty string "" to disable a default map)
  keymaps = {
    add_file = "<leader>a",     -- Add current file
    toggle_ui = "<C-e>",        -- Toggle the list UI
    save_list = "<leader>hs",   -- Save current list (prompts for name)
    load_list = "<leader>hl",   -- Load list (shows selector UI)
    -- Navigation keymaps (generates 1-9 by default if key exists)
    nav_file_1 = "<leader>1",
    nav_file_2 = "<leader>2",
    nav_file_3 = "<leader>3",
    nav_file_4 = "<leader>4",
    -- nav_file_5 = "<leader>5", -- etc.
    -- nav_file_9 = "<leader>9",
  }
})
```

See the `init.lua` file for the complete structure of the default configuration.

## Usage

### Core Workflow

1.  **Add Files:** Navigate to a file you want to bookmark and press `<leader>a` (or your configured keymap) or run `:HarpoonerAdd`.
2.  **View List:** Press `<C-e>` (or your configured keymap) or run `:HarpoonerList` to open the UI window showing the current bookmarks.
3.  **Navigate:** Press `<leader>1`, `<leader>2`, etc. (or your configured keymaps) to instantly jump to the corresponding file in your list.
4.  **Manage in UI:** While the UI window is open:
    * Move cursor to a file entry.
    * Press `<CR>` to open that file.
    * Press `dd` to remove that file *entry* from the *current* list.
    * Press `J` or `K` to move the selected entry down or up.
    * Press `q` or `<Esc>` to close the UI.
5.  **Save a List:** Press `<leader>hs` (or your configured keymap). You'll be prompted to enter a name. The current list of bookmarks will be saved under that name.
6.  **Load a List:** Press `<leader>hl` (or your configured keymap) or run `:HarpoonerLoadList` without arguments. A selector UI will appear, allowing you to choose a previously saved list to load. Alternatively, run `:HarpoonerLoadList <list_name>` to load it directly. Loading replaces the current list.
7.  **Delete a Saved List:** Run the command `:HarpoonerDeleteList <list_name>`. You will be asked for confirmation before the saved list file is deleted.

### Default Keymaps (Global)

* `<leader>a`: Add current file to the list (`HarpoonerAdd`).
* `<C-e>`: Toggle the Harpooner UI window (`HarpoonerList`).
* `<leader>hs`: Prompt to save the current list under a name.
* `<leader>hl`: Show selector UI to load a saved list (`HarpoonerLoadList`).
* `<leader>1` - `<leader>9` (if configured): Navigate directly to the file at that index.

### UI Window Keymaps

These keymaps are active *only* when the Harpooner UI floating window is open and focused:

* `<CR>`: Open the file under the cursor.
* `dd`: Delete the file *entry* under the cursor from the current list.
* `J`: Move the selected entry down.
* `K`: Move the selected entry up.
* `q`: Close the Harpooner UI window.
* `<Esc>`: Close the Harpooner UI window.

### Commands

* `:HarpoonerAdd`: Add the current file to the list.
* `:HarpoonerList` / `:HarpoonerEdit`: Toggle the UI window.
* `:HarpoonerSaveList <name>`: Save the current list of bookmarks to a file named `<name>.json`.
* `:HarpoonerLoadList [name]`: Load the list saved as `<name>.json`. If `<name>` is omitted, shows a UI selector to choose a list.
* `:HarpoonerDeleteList <name>`: Deletes the saved list file `<name>.json` after confirmation.

## License

This plugin is released under a **MIT**. Please see the header comments in the Lua files or contact the author (`hobo`) for more details. ```


