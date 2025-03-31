-- File: init.lua
-- Author: hobo
-- License: proprietary
-- Description: main entry point for the plugin
-- Version: 0.0.1
-- Created: 2025-03-31
-- Last modified: 2025-03-31
-- Repo: https://github.com/LetsRipp/harpooner.git

local M = {}

local Data = require('harpooner-nvim.data')
local UI -- UI instance, created in setup

-- Holds the single UI instance
local ui_instance = nil

-- Default configuration
local default_config = {
    -- Add any top-level config here if needed
    -- UI specific config is handled within ui.lua defaults now
    save_on_exit = true, -- Automatically save current list state on Vim exit
    ui = { -- Pass UI specific options here
        ui_width_ratio = 0.5,
        ui_max_width = 100,
        height_in_lines = 12,
        border = "rounded",
        -- Add other UI options matching ui.lua defaults you want to override
    },
    keymaps = {
        add_file = "<leader>a",
        toggle_ui = "<C-e>",
        save_list = "<leader>hs",
        load_list = "<leader>hl",
        nav_file_1 = "<leader>1",
        nav_file_2 = "<leader>2",
        nav_file_3 = "<leader>3",
        nav_file_4 = "<leader>4",
        -- Add more nav file keymaps if needed (maybe generate up to 9?)
    }
}

local user_config = {} -- To be populated by setup

-- function to use keybinding to save list of bookmarks
local function prompt_and_save_list()
    vim.ui.input({ prompt = "Save Harpooner list as: " }, function(list_name)
        if list_name and list_name ~= "" then
            -- Escape the name just in case, although less critical than file paths
            local escaped_name = vim.fn.fnameescape(list_name)
            -- Construct and execute the command
            vim.cmd("HarpoonerSaveList " .. escaped_name)
        else
            vim.notify("Harpooner: List save cancelled.", vim.log.levels.INFO)
        end
    end)
end

--[[ ======================================================================
    Plugin Setup Function
   ====================================================================== ]]

---@param config_override? table User configuration table
function M.setup(config_override)
    user_config = vim.tbl_deep_extend('force', {}, default_config, config_override or {})

    -- Initialize data module (loads last list)
    Data.initialize()

    -- Create the UI instance, passing user UI settings and data module
    -- Ensure UI is required *after* Data is initialized if UI needs data on creation
    UI = require('harpooner-nvim.ui')
    ui_instance = UI.new(user_config.ui, Data)

    -- Define User Commands
    vim.api.nvim_create_user_command('HarpoonerAdd', function()
        local current_file = vim.api.nvim_buf_get_name(0)
        Data.add_current_file_path(current_file)
    end, { desc = "Harpooner: Add current file to the list" })

    vim.api.nvim_create_user_command('HarpoonerList', function()
        ui_instance:toggle_quick_menu()
    end, { desc = "Harpooner: Toggle bookmark list UI" })

    vim.api.nvim_create_user_command('HarpoonerEdit', function()
         ui_instance:toggle_quick_menu()
    end, { desc = "Harpooner: Edit bookmark list (same as List)" })

    vim.api.nvim_create_user_command('HarpoonerSaveList', function(opts)
        if not opts.args or opts.args == '' then
            vim.notify("Harpooner: Usage: HarpoonerSaveList <list_name>", vim.log.levels.ERROR)
            return
        end
        Data.save_current_list_as(opts.args)
    end, {
        desc = "Harpooner: Save current list to a named file",
        nargs = 1,
        complete = function(arglead, cmdline, cursorpos)
             -- Simple completion example, could be improved
             return {"my_project_list", "temp_bookmarks"}
        end
    })

    vim.api.nvim_create_user_command('HarpoonerLoadList', function(opts)
         if opts.fargs and #opts.fargs > 0 then
             -- Load directly if name is provided
             Data.load_list(opts.fargs[1])
             -- Optional: Refresh UI if open
             if ui_instance:is_open() then ui_instance:_refresh_content() end
         else
            -- Use UI selector if no name provided
            UI.select_and_load_list()
         end
    end, {
        desc = "Harpooner: Load a named list (shows selector if no name given)",
        nargs = "?", -- 0 or 1 argument
        complete = function(arglead, cmdline, cursorpos)
            -- Provide completion based on saved list names
            return Data.get_saved_list_names()
        end
    })

    -- Setup Global Keymaps
    local function map(lhs, rhs, desc)
        if lhs and lhs ~= '' then -- Allow disabling maps by setting to empty string or nil
            vim.keymap.set('n', lhs, rhs, { silent = true, noremap = true, desc = "Harpooner: " .. desc })
        end
    end

    -- Use tbl_get to safely access potentially nil keys from user config
    local keymaps = user_config.keymaps or {}

    -- keymaps
    map(keymaps.add_file, '<Cmd>HarpoonerAdd<CR>', "Add current file")
    map(keymaps.toggle_ui, '<Cmd>HarpoonerList<CR>', "Toggle UI")
    map(keymaps.save_list, function() prompt_and_save_list() end, "Save current list as...")
    map(keymaps.load_list, function() UI.select_and_load_list() end, "Load bookmark list")

    -- Keybound File Recall (Example for 1-4)
    local function create_nav_map(index)
        local key = user_config.keymaps['nav_file_' .. index]
        if key and key ~= '' then
            map(key, function()
                local path = Data.get_path_by_index(index)
                if path then
                    -- Close UI if it happens to be open when using direct nav key
                    if ui_instance:is_open() then ui_instance:close_menu() end
                    vim.schedule(function() -- Schedule to ensure UI close finishes
                        vim.cmd('edit ' .. vim.fn.fnameescape(path))
                    end)
                else
                    vim.notify("Harpooner: No file at index " .. index, vim.log.levels.WARN)
                end
            end, "Navigate to file " .. index)
        end
    end

    for i = 1, 9 do -- Create maps for configured nav keys (up to 9 default)
        create_nav_map(i)
    end

    -- Auto-save on exit if configured
    if user_config.save_on_exit then
        local group = vim.api.nvim_create_augroup("HarpoonerAutoSave", { clear = true })
        vim.api.nvim_create_autocmd("VimLeavePre", {
            group = group,
            pattern = "*",
            callback = function()
                Data.save_on_exit()
            end,
            desc = "Harpooner: Save current list state before exiting"
        })
    end

    print("Harpooner setup complete.")
end

-- Optional: Allow getting the UI instance if needed elsewhere (e.g., for refresh after load)
function M.get_ui_instance()
    return ui_instance
end


return M
