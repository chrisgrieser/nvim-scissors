local M = {}
--------------------------------------------------------------------------------

---@param allSnippets SnippetObj[]
function M.selectSnippet(allSnippets)
	local prompt = "Select Snippet:"

	local hasTelescope, _ = pcall(require, "telescope")
	local picker = hasTelescope and "telescope" or "vim-ui-select"

	require("scissors.picker." .. picker).selectSnippet(allSnippets, prompt)
end

--------------------------------------------------------------------------------

---@param item snipFile
---@return string
local function fileDisplay(item)
	local snippetDir = require("scissors.config").config.snippetDir
	local relPath = item.path:sub(#snippetDir + 2)
	local shortened = relPath:gsub("%.jsonc?$", "")
	return shortened
end

---@param allSnipFiles snipFile[]
---@param bodyPrefill string[]
function M.addSnippet(allSnipFiles, bodyPrefill)
	local prompt = "Select file for new snippet:"

	local hasTelescope, _ = pcall(require, "telescope")
	local picker = hasTelescope and "telescope" or "vim-ui-select"

	require("scissors.picker." .. picker).addSnippet(allSnipFiles, fileDisplay, prompt, bodyPrefill)
end
--------------------------------------------------------------------------------
return M
