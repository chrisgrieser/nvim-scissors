local M = {}
--------------------------------------------------------------------------------

---@class (exact) snippetObj VSCode snippet json
---@field fullPath string (key only set by this plugin)
---@field originalKey? string if not set, is a new snippet (key only set by this plugin)
---@field prefix string|string[]
---@field body string|string[]
---@field description? string

---@param msg string
---@param level? "info"|"warn"|"error"|"debug"|"trace"
function M.notify(msg, level)
	if not level then level = "info" end
	vim.notify(msg, vim.log.levels[level:upper()], { title = "nvim-scissors" })
end

--------------------------------------------------------------------------------
return M
