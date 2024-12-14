local version = vim.version()
if version.major == 0 and version.minor < 10 then
	vim.notify("nvim-scissors requires at least nvim 0.10.", vim.log.levels.WARN)
	return
end
--------------------------------------------------------------------------------

local M = {}

-- PERF do not require other submodules here, since that loads the entire codebase
-- of the plugin on initialization instead of lazy-loading the code only when needed.

---@param userConfig? Scissors.Config
function M.setup(userConfig) require("scissors.config").setupPlugin(userConfig) end

function M.addNewSnippet(exCmdArgs) require("scissors.prepare-selection").addNewSnippet(exCmdArgs) end
function M.editSnippet() require("scissors.prepare-selection").editSnippet() end

--------------------------------------------------------------------------------

vim.api.nvim_create_user_command(
	"ScissorsAddNewSnippet",
	function(args) require("scissors.prepare-selection").addNewSnippet(args) end,
	{ desc = "Add new snippet.", range = true }
)

vim.api.nvim_create_user_command(
	"ScissorsEditSnippet",
	function() require("scissors.prepare-selection").editSnippet() end,
	{ desc = "Edit existing snippet." }
)

vim.api.nvim_create_user_command(
	"ScissorsCreateSnippetsForSnippetVars",
	function() require("scissors.vscode-format.snippet-variables").createSnippetFile() end,
	{ desc = "Create snippets for VSCode snippet variables." }
)

--------------------------------------------------------------------------------
return M
