local M = {}
--------------------------------------------------------------------------------

---@param allSnippets Scissors.SnippetObj[]
function M.selectSnippet(allSnippets)
	local icon = require("scissors.config").config.icons.scissors
	local prompt = vim.trim(icon .. " Select Snippet:")

	local hasTelescope, _ = pcall(require, "telescope")
	local picker = hasTelescope and "telescope" or "vim-ui-select"

	require("scissors.picker." .. picker).selectSnippet(allSnippets, prompt)
end

--------------------------------------------------------------------------------

---@param item Scissors.snipFile
---@return string
local function fileDisplay(item)
	local snippetDir = require("scissors.config").config.snippetDir
	local relPath = item.path:sub(#snippetDir + 2)
	local shortened = relPath:gsub("%.jsonc?$", "")
	return shortened
end

---@param allSnipFiles Scissors.snipFile[]
---@param bodyPrefill string[]
function M.addSnippet(allSnipFiles, bodyPrefill)
	local icon = require("scissors.config").config.icons.scissors
	local prompt = vim.trim(icon .. " Select file for new snippet:")

	local hasTelescope, _ = pcall(require, "telescope")
	local picker = hasTelescope and "telescope" or "vim-ui-select"

	require("scissors.picker." .. picker).addSnippet(allSnipFiles, fileDisplay, prompt, bodyPrefill)
end
--------------------------------------------------------------------------------
return M
