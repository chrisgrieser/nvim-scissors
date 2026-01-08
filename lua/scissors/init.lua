local version = vim.version()
if version.major == 0 and version.minor < 11 then
	vim.notify("nvim-scissors requires at least nvim 0.11.", vim.log.levels.WARN)
	return
end
--------------------------------------------------------------------------------

local M = {}

---@param userConfig? Scissors.Config
function M.setup(userConfig) require("scissors.config").setupPlugin(userConfig) end

function M.addNewSnippet() require("scissors.1-prepare-selection").addNewSnippet() end

function M.editSnippet() require("scissors.1-prepare-selection").editSnippet() end

--------------------------------------------------------------------------------
return M
