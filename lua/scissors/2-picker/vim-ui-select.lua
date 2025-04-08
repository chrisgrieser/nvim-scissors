local M = {}

local edit = require("scissors.3-edit-popup")
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@param snippets Scissors.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	vim.ui.select(snippets, {
		prompt = prompt,
		format_item = function(snip)
			local filename = vim.fs.basename(snip.fullPath):gsub("%.json$", "")
			return u.snipDisplayName(snip) .. " [" .. filename .. "]"
		end,
	}, function(snip)
		if not snip then return end
		edit.editInPopup(snip, "update")
	end)
end

--------------------------------------------------------------------------------

---@param allSnipFiles Scissors.snipFile[]
---@param bodyPrefill string[] for the new snippet
function M.addSnippet(allSnipFiles, bodyPrefill)
	local icon = require("scissors.config").config.icons.scissors
	local snippetDir = require("scissors.config").config.snippetDir

	vim.ui.select(allSnipFiles, {
		prompt = vim.trim(icon .. " Select file for new snippet: "),
		format_item = function(item)
			local relPath = item.path:sub(#snippetDir + 2)
			return relPath:gsub("%.jsonc?$", "")
		end,
	}, function(snipFile)
		if not snipFile then return end
		edit.createNewSnipAndEdit(snipFile, bodyPrefill)
	end)
end
--------------------------------------------------------------------------------
return M
