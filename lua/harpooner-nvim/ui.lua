-- File: ui.lua
-- Author: hobo
-- License: proprietery
-- Description: UI for harpooner
-- Version: 0.0.1
-- Created: 2025-03-31
-- Last modified: 2025-03-31
-- Repo: https://github.com/LetsRipp/harpooner.git

local M = {} -- The UI module itself
local HarpoonUI = {} -- The class/metatable for UI instances
HarpoonUI.__index = HarpoonUI

local Data -- Reference to the data module, injected later

-- Helper for logging (replace with a real logger if needed)
local Logger = {
    log = function(...)
        -- print(vim.inspect({...})) -- Basic print debugging
    end
}

-- Configuration (defaults, can be overridden in setup)
local config = {
    ui_width_ratio = 0.6,
    ui_max_width = 80,
    ui_fallback_width = 60,
    height_in_lines = 10,
    border = "single",
    title = "Harpooner Bookmarks",
    title_pos = "center",
    save_on_toggle = true, -- Save current list state when closing UI
    show_numbers = true,
}

--- Simple merge of user config over defaults
local function merge_config(user_config)
  user_config = user_config or {}
  for k, v in pairs(user_config) do
    config[k] = v
  end
end

---@param settings table User configuration
---@param data_module table The required data module
---@return HarpoonUI
function M.new(settings, data_module)
    merge_config(settings)
    Data = data_module -- Store reference to data module
    return setmetatable({
        win_id = nil,
        bufnr = nil,
        settings = config, -- Use merged config
        closing = false,
    }, HarpoonUI)
end

function HarpoonUI:is_open()
    return self.win_id ~= nil and vim.api.nvim_win_is_valid(self.win_id)
end

function HarpoonUI:close_menu()
    if self.closing or not self:is_open() then
        return
    end
    self.closing = true
    Logger:log("ui#close_menu", { win = self.win_id, bufnr = self.bufnr })

    -- Save state before closing if configured
    if self.settings.save_on_toggle then
        Data.save_current_list_state()
    end

    local win_id = self.win_id
    local bufnr = self.bufnr

    -- Important: Clear state *before* potentially triggering autocmds on close/delete
    self.win_id = nil
    self.bufnr = nil

    -- Schedule cleanup to avoid issues with autocmds potentially
    -- trying to access the window/buffer being closed.
    vim.schedule(function()
        if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
        if win_id ~= nil and vim.api.nvim_win_is_valid(win_id) then
            vim.api.nvim_win_close(win_id, true)
        end
        self.closing = false -- Reset closing flag after cleanup
    end)
end

---@param toggle_opts? table Overrides for UI creation (border, title etc.)
---@return number win_id, number bufnr
function HarpoonUI:_create_window(toggle_opts)
    toggle_opts = toggle_opts or {}
    local win_info = vim.api.nvim_list_uis()[1] -- Get primary UI dimensions
    local term_width = (win_info and win_info.width) or 80
    local term_height = (win_info and win_info.height) or 24

    local width = math.floor(term_width * (toggle_opts.ui_width_ratio or self.settings.ui_width_ratio))
    width = math.min(width, toggle_opts.ui_max_width or self.settings.ui_max_width)
    width = math.max(width, toggle_opts.ui_fallback_width or self.settings.ui_fallback_width) -- Ensure minimum width

    local height = toggle_opts.height_in_lines or self.settings.height_in_lines
    height = math.min(height, term_height - 4) -- Don't make it too tall

    local bufnr = vim.api.nvim_create_buf(false, true) -- Create a scratch buffer
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'harpooner') -- Custom filetype for syntax/keymaps

    local win_id = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        title = toggle_opts.title or self.settings.title,
        title_pos = toggle_opts.title_pos or self.settings.title_pos,
        row = math.floor(((term_height - height) / 2) - 1),
        col = math.floor((term_width - width) / 2),
        width = width,
        height = height,
        style = "minimal",
        border = toggle_opts.border or self.settings.border,
    })

    if win_id == 0 then
        Logger:log("ui#_create_window failed")
        vim.api.nvim_buf_delete(bufnr, { force = true }) -- Clean up buffer
        error("Failed to create Harpooner window")
    end

    -- Set options for the new window/buffer
    vim.api.nvim_set_option_value("number", self.settings.show_numbers, { win = win_id })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win_id }) -- Usually false for lists
    vim.api.nvim_set_option_value("cursorline", true, { win = win_id })
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr }) -- Initially not modifiable

    self:_setup_keymaps(bufnr) -- Setup buffer-local keymaps

    return win_id, bufnr
end

--- Sets up keymaps specific to the Harpooner UI buffer
---@param bufnr number The buffer number for the UI
function HarpoonUI:_setup_keymaps(bufnr)
    local function map(lhs, rhs, desc)
        vim.keymap.set('n', lhs, rhs, { buffer = bufnr, silent = true, noremap = true, desc = desc })
    end

    -- Recall File: Open selected file path
    map('<CR>', function()
        local line_nr = vim.api.nvim_win_get_cursor(self.win_id)[1]
        local path = Data.get_path_by_index(line_nr)
        if path then
            self:close_menu() -- Close UI first
            -- Use vim.schedule to ensure UI is closed before edit command runs
            vim.schedule(function()
                 -- Check if file exists? Maybe `vim.fn.filereadable(path)`
                vim.cmd('edit ' .. vim.fn.fnameescape(path))
            end)
        else
            vim.notify("Harpooner: Invalid line selected", vim.log.levels.WARN)
        end
    end, "Open selected file")

    -- Delete File Path: Remove item from list
    map('dd', function()
        local line_nr = vim.api.nvim_win_get_cursor(self.win_id)[1]
        if Data.delete_path_by_index(line_nr) then
            self:_refresh_content() -- Update display after deletion
            -- Try to keep cursor position reasonable
            local new_max_line = #Data.get_current_list()
            if new_max_line == 0 then return end
            local new_line = math.min(line_nr, new_max_line)
            vim.api.nvim_win_set_cursor(self.win_id, {new_line, 0})
        end
    end, "Delete selected entry")

    -- Reorder Paths (Example using J/K)
    map('J', function() -- Move item down
      local line_nr = vim.api.nvim_win_get_cursor(self.win_id)[1]
      if line_nr < #Data.get_current_list() then
          if Data.reorder_path(line_nr, line_nr + 1) then
              self:_refresh_content()
              vim.api.nvim_win_set_cursor(self.win_id, {line_nr + 1, 0})
          end
      end
    end, "Move item down")

     map('K', function() -- Move item up
      local line_nr = vim.api.nvim_win_get_cursor(self.win_id)[1]
      if line_nr > 1 then
          if Data.reorder_path(line_nr, line_nr - 1) then
              self:_refresh_content()
              vim.api.nvim_win_set_cursor(self.win_id, {line_nr - 1, 0})
          end
      end
    end, "Move item up")


    -- Close UI
    map('q', function() self:close_menu() end, "Close Harpooner")
    map('<Esc>', function() self:close_menu() end, "Close Harpooner")

    -- Add more keymaps as needed (e.g., for jumping, editing paths directly?)
end

--- Refreshes the content of the UI buffer
function HarpoonUI:_refresh_content()
    if not self:is_open() then return end

    local current_list = Data.get_current_list()
    local display_lines = {}
    if #current_list == 0 then
        table.insert(display_lines, "(empty list)")
    else
        for _, path in ipairs(current_list) do
            -- Maybe shorten path for display? fnamemodify(path, ':~:.')
            table.insert(display_lines, vim.fn.fnamemodify(path, ':p:~:.')) -- Show path relative to home or cwd
        end
    end

    vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, display_lines)
    vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
    vim.api.nvim_set_current_win(self.win_id) -- Ensure focus remains
end


--- Toggles the display of the current bookmark list.
---@param opts? HarpoonToggleOptions Optional overrides for UI creation.
function HarpoonUI:toggle_quick_menu(opts)
    if self:is_open() then
        Logger:log("ui#toggle_quick_menu#closing")
        self:close_menu()
        return
    end

    Logger:log("ui#toggle_quick_menu#opening")
    local win_id, bufnr = self:_create_window(opts)

    self.win_id = win_id
    self.bufnr = bufnr

    self:_refresh_content() -- Populate with current list data
end

--- Uses vim.ui.select to let the user pick a saved list.
--- Calls data.load_list on selection.
function M.select_and_load_list()
    local list_names = Data.get_saved_list_names()
    if #list_names == 0 then
        vim.notify("Harpooner: No saved lists found.", vim.log.levels.INFO)
        return
    end

    vim.ui.select(list_names, {
        prompt = "Select list to load:",
        format_item = function(item) return "󰂺 " .. item end -- Example using Nerd Font icon
    }, function(choice)
        if choice then
            Data.load_list(choice)
            -- If UI is open, refresh it
            -- Find the active UI instance (might need a better way if multiple instances are possible)
            -- For now, assume only one global instance managed by init.lua
            -- local ui_instance = require('harpooner').get_ui_instance()
            -- if ui_instance and ui_instance:is_open() then
            --    ui_instance:_refresh_content()
            -- end
             vim.notify("Harpooner: Loaded list: " .. choice)
        else
            vim.notify("Harpooner: List selection cancelled.", vim.log.levels.INFO)
        end
    end)
end


return M
