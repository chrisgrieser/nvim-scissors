local M = {}

local edit = require("scissors.3-edit-popup")
local u = require("scissors.utils")
local vb = require("scissors.vscode-format.validate-bootstrap")
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
---@param offerBootstrap? "offer-bootstrap"
function M.addSnippet(allSnipFiles, bodyPrefill, offerBootstrap)
	local icon = require("scissors.config").config.icons.scissors
	local snippetDir = require("scissors.config").config.snippetDir
	local bufferFt = vim.bo.filetype
	if offerBootstrap then table.insert(allSnipFiles, "bootstrap-for-ft") end

	vim.ui.select(allSnipFiles, {
		prompt = vim.trim(icon .. " Select file for new snippet: "),
		format_item = function(item)
			if item == "bootstrap-for-ft" then
				return ("[New snippet file for `%s`]"):format(bufferFt)
			else
			end
			local relPath = item.path:sub(#snippetDir + 2)
			return relPath:gsub("%.jsonc?$", "")
		end,
	}, function(selection)
		if not selection then return end
		local snipFile
		if selection == "bootstrap-for-ft" then
			snipFile = vb.bootstrapSnippetFile(bufferFt)
			u.notify(("Created new snippet file for `%s`."):format(bufferFt))
		else
			snipFile = selection --[[@as Scissors.snipFile]]
		end
		edit.createNewSnipAndEdit(snipFile, bodyPrefill)
	end)
end
--------------------------------------------------------------------------------
return M
