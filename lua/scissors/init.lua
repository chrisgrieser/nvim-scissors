local version = vim.version()
if version.major == 0 and version.minor < 12 then
	local msg = "nvim-scissors requires at least nvim 0.12.\n"
		.. "The latest commit supporting nvim 0.11 is {{placeholder}}."
	vim.notify(msg, vim.log.levels.WARN)
	return
end
--------------------------------------------------------------------------------

local M = {}

---@param userConfig? Scissors.Config
function M.setup(userConfig) require("scissors.config").setupPlugin(userConfig) end

function M.addNewSnippet(exCmdArgs) require("scissors.1-prepare-selection").addNewSnippet(exCmdArgs) end

function M.editSnippet() require("scissors.1-prepare-selection").editSnippet() end

--------------------------------------------------------------------------------
return M
