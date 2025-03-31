-- File: data.lua
-- Author: hobo
-- License: proprietery
-- Description: handles lists in memory and saving/loading lists
-- -- Version: 0.0.1
-- Created: 2025-03-31
-- Last modified: 2025-03-31
-- Repo: https://github.com/hobo/harpooner.git

local M = {}

-- Where to save list data
-- Consider making this configurable
local data_dir = vim.fn.stdpath('data') .. '/harpooner'
local current_list_file = data_dir .. '/_current_list.json' -- Or store last loaded name

-- In-memory state
local state = {
    current_list = {}, -- List of file path strings
    current_list_name = nil, -- Name of the list currently loaded (optional, could be used for saving)
    is_dirty = false, -- Track if changes need saving
}

-- Ensure data directory exists
local function ensure_data_dir()
    if vim.fn.isdirectory(data_dir) == 0 then
        vim.fn.mkdir(data_dir, 'p')
    end
end

--[[
    Serialization/Deserialization Helpers
    Using JSON as it's simple and built-in.
]]
local function serialize(data)
    return vim.fn.json_encode(data)
end

local function deserialize(json_string)
    if json_string == nil or json_string == '' then
        return nil, "Empty data"
    end
    local ok, data = pcall(vim.fn.json_decode, json_string)
    if not ok then
        return nil, "Failed to decode JSON: " .. tostring(data) -- data contains error message on failure
    end
    return data
end

--- Reads a file safely
---@param file_path string
---@return string? content, string? error
local function read_file(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Could not open file for reading: " .. file_path
    end
    local content = file:read("*a")
    file:close()
    return content
end

--- Writes data to a file safely
---@param file_path string
---@param content string
---@return boolean success, string? error
local function write_file(file_path, content)
    ensure_data_dir()
    local file = io.open(file_path, "w")
    if not file then
        return false, "Could not open file for writing: " .. file_path
    end
    local ok, err = file:write(content)
    file:close() -- Close regardless of write success
    if not ok then
        return false, "Failed to write to file: " .. tostring(err)
    end
    return true
end

--- Loads the last used list or initializes an empty one
function M.initialize()
    ensure_data_dir()
    -- Try loading the last known 'current' list
    local content, err = read_file(current_list_file)
    if content then
        local data, decode_err = deserialize(content)
        if data and type(data) == 'table' then
            state.current_list = data
            -- Maybe store/load the name too if current_list_file contains {name=..., list=...}
        else
            vim.notify("Harpooner: Error loading last list: " .. (decode_err or "Invalid data"), vim.log.levels.WARN)
            state.current_list = {} -- Start fresh on error
        end
    else
        -- No previous list found, start empty
        state.current_list = {}
        print ("Harpooner: I've loaded nothing. Nothing.")
    end
    state.is_dirty = false
end

--[[ ======================================================================
    2.2.1 Path Save Function
   ====================================================================== ]]

--- Adds the given file path to the current list if it's not already present.
---@param file_path string Full path to the file.
function M.add_current_file_path(file_path)
    if not file_path or file_path == '' then
        vim.notify("Harpooner: No file path to add.", vim.log.levels.WARN)
        return
    end

    -- Prevent duplicates (optional, but usually desired)
    for _, existing_path in ipairs(state.current_list) do
        if existing_path == file_path then
            vim.notify("Harpooner: Path already in list: " .. vim.fn.fnamemodify(file_path, ":t"), vim.log.levels.INFO)
            return
        end
    end

    table.insert(state.current_list, file_path)
    state.is_dirty = true
    vim.notify("Harpooner: Added: " .. vim.fn.fnamemodify(file_path, ":t"))
    -- Maybe trigger a UI refresh if it's open
end

--[[ ======================================================================
    2.2.2 List Save Function
   ====================================================================== ]]

--- Saves the current list of file paths to a named file.
---@param list_name string The name to save the list under.
function M.save_current_list_as(list_name)
    if not list_name or list_name == '' or list_name == '_current_list' then
        vim.notify("Harpooner: Invalid list name provided.", vim.log.levels.ERROR)
        return
    end

    local file_path = data_dir .. '/' .. list_name .. '.json'
    local content_to_save = serialize(state.current_list)

    local ok, err = write_file(file_path, content_to_save)
    if ok then
        vim.notify("Harpooner: List saved as '" .. list_name .. "'")
        state.current_list_name = list_name -- Update the name of the current list
        state.is_dirty = false -- It's now saved under this name
        -- Optionally save this name as the 'last used' list name
        -- write_file(data_dir .. '/_last_list_name.txt', list_name)
    else
        vim.notify("Harpooner: Error saving list '" .. list_name .. "': " .. err, vim.log.levels.ERROR)
    end
end

--- Saves the current list state to the default 'current_list_file'.
--- Often called automatically (e.g., on exit or UI close).
function M.save_current_list_state()
    if not state.is_dirty then
        return -- No changes to save
    end

    local content_to_save = serialize(state.current_list)
    local ok, err = write_file(current_list_file, content_to_save)
    if ok then
        state.is_dirty = false
        print("Harpooner: Current list state saved.")
    else
        vim.notify("Harpooner: Error saving current list state: " .. err, vim.log.levels.ERROR)
    end
end

--[[ ======================================================================
    2.3.1 Recall File Function (Data Part)
   ====================================================================== ]]

--- Gets the file path at a specific index (1-based) from the current list.
---@param index number The 1-based index in the list.
---@return string? path The file path or nil if index is invalid.
function M.get_path_by_index(index)
    return state.current_list[index]
end

--- Returns the entire current list.
---@return table list A table of file path strings.
function M.get_current_list()
    return vim.deepcopy(state.current_list) -- Return a copy to prevent accidental modification
end

--[[ ======================================================================
    2.3.2 Recall List Function (Data Part)
   ====================================================================== ]]

--- Loads a named list, making it the current list.
---@param list_name string The name of the list to load.
function M.load_list(list_name)
    if not list_name or list_name == '' then
        vim.notify("Harpooner: No list name provided.", vim.log.levels.ERROR)
        return
    end

    local file_path = data_dir .. '/' .. list_name .. '.json'
    local content, read_err = read_file(file_path)

    if not content then
        vim.notify("Harpooner: Could not load list '" .. list_name .. "': " .. (read_err or "File not found"), vim.log.levels.ERROR)
        return
    end

    local data, decode_err = deserialize(content)
    if data and type(data) == 'table' then
        -- Optional: Save current list before overwriting?
        -- if state.is_dirty then M.save_current_list_state() end

        state.current_list = data
        state.current_list_name = list_name
        state.is_dirty = false -- Freshly loaded, not dirty yet
        M.save_current_list_state() -- Update the default save file
        vim.notify("Harpooner: Loaded list '" .. list_name .. "'")
        -- Trigger UI refresh if open
    else
        vim.notify("Harpooner: Error decoding list '" .. list_name .. "': " .. (decode_err or "Invalid data"), vim.log.levels.ERROR)
    end
end

--[[ ======================================================================
   List Deletion Function
   ====================================================================== ]]

--- Deletes a saved list file after confirmation.
---@param list_name string The name of the list to delete.
function M.delete_list(list_name)
    if not list_name or list_name == '' then
        vim.notify("Harpooner: No list name provided for deletion.", vim.log.levels.ERROR)
        return false
    end

    -- Prevent deleting the internal current list state file directly
    if list_name == '_current_list' then
         vim.notify("Harpooner: Cannot delete the internal '_current_list' state file.", vim.log.levels.ERROR)
         return false
    end

    local file_path = data_dir .. '/' .. list_name .. '.json'

    -- Check if the file actually exists
    if vim.fn.filereadable(file_path) == 0 then
        vim.notify("Harpooner: List '" .. list_name .. "' not found.", vim.log.levels.ERROR)
        return false
    end

    -- Ask for confirmation before deleting
    vim.ui.confirm("Are you sure you want to delete the Harpooner list '" .. list_name .. "'?", function(confirmed)
        if confirmed then
            -- Attempt to delete the file
            local ok, err = pcall(vim.fn.delete, file_path) -- Use pcall for safety

            if ok then
                vim.notify("Harpooner: Deleted list '" .. list_name .. "'.")

                -- If the deleted list was the currently loaded one, clear its name
                if state.current_list_name == list_name then
                    state.current_list_name = nil
                    -- Keep state.current_list in memory until user loads another or exits
                    -- state.is_dirty doesn't need changing here conceptually
                end
                -- NOTE: Command completion caches might need Neovim restart or
                -- specific handling if you want immediate update without restart.
                return true
            else
                vim.notify("Harpooner: Error deleting list '" .. list_name .. "': " .. tostring(err), vim.log.levels.ERROR)
                return false
            end
        else
            vim.notify("Harpooner: List deletion cancelled.", vim.log.levels.INFO)
            return false
        end
    end)
end

--- Gets the names of all saved lists.
---@return table list A list of saved list names (strings).
function M.get_saved_list_names()
    ensure_data_dir()
    local names = {}
    -- Use vim.fn.globpath for cross-platform compatibility
    local files = vim.fn.globpath(data_dir, '*.json', false, true)
    for _, file_path in ipairs(files) do
        local name = vim.fn.fnamemodify(file_path, ':t:r') -- Get filename without extension
        if name ~= '_current_list' then -- Exclude the internal state file
            table.insert(names, name)
        end
    end
    return names
end


--[[ ======================================================================
    2.4.1 Delete File Path Function (Data Part)
   ====================================================================== ]]

--- Deletes the file path at the specified index (1-based) from the current list.
---@param index number The 1-based index to remove.
function M.delete_path_by_index(index)
    if index >= 1 and index <= #state.current_list then
        local removed_path = table.remove(state.current_list, index)
        state.is_dirty = true
        vim.notify("Harpooner: Removed: " .. vim.fn.fnamemodify(removed_path, ":t"))
        -- Trigger UI refresh
        return true
    else
        vim.notify("Harpooner: Invalid index to delete: " .. index, vim.log.levels.WARN)
        return false
    end
end

--- Moves the item at `from_index` to `to_index` (1-based indices).
function M.reorder_path(from_index, to_index)
    if from_index < 1 or from_index > #state.current_list or
       to_index < 1 or to_index > #state.current_list or
       from_index == to_index then
        vim.notify("Harpooner: Invalid reorder indices.", vim.log.levels.WARN)
        return false
    end

    local item = table.remove(state.current_list, from_index)
    table.insert(state.current_list, to_index, item)
    state.is_dirty = true
    vim.notify("Harpooner: Item moved.")
    -- Trigger UI refresh
    return true
end


--[[ ======================================================================
    Cleanup
   ====================================================================== ]]
function M.save_on_exit()
    -- This function can be called via autocommand
    M.save_current_list_state()
end


return M
