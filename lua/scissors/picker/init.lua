local M = {}

local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@param snip SnippetObj
---@return string
local function snipCreateDisplay(snip)
	local snipName = u.snipDisplayName(snip)
	local filename = vim.fs.basename(snip.fullPath):gsub("%.json$", "")
	return ("%s\t\t[%s]"):format(snipName, filename)
end

---@param allSnippets SnippetObj[]
function M.selectSnippet(allSnippets)
	local prompt = "Select Snippet:"
	local hasTelescope, _ = pcall(require, "telescope")
	if hasTelescope then
		require("scissors.picker.telescope").selectSnippet(allSnippets, snipCreateDisplay, prompt)
	else
		require("scissors.picker.vim-ui-select").selectSnippet(allSnippets, snipCreateDisplay, prompt)
	end
end
--------------------------------------------------------------------------------

---@param item snipFile
---@return string
local function fileCreateDisplay(item)
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
	if hasTelescope then
		require("scissors.picker.telescope").addSnippet(
			allSnipFiles,
			fileCreateDisplay,
			prompt,
			bodyPrefill
		)
	else
		require("scissors.picker.vim-ui-select").addSnippet(
			allSnipFiles,
			fileCreateDisplay,
			prompt,
			bodyPrefill
		)
	end
end
--------------------------------------------------------------------------------
return M
