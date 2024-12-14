local M = {}

local edit = require("scissors.3-edit-popup")
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@param snippets Scissors.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	local backdropAugroup = require("scissors.backdrop").setup("DressingSelect")

	vim.ui.select(snippets, {
		prompt = prompt,
		format_item = function(snip)
			local filename = vim.fs.basename(snip.fullPath):gsub("%.json$", "")
			return u.snipDisplayName(snip) .. " [" .. filename .. "]"
		end,
		kind = "nvim-scissors.snippetSearch",
	}, function(snip)
		vim.api.nvim_del_augroup_by_id(backdropAugroup)
		if snip then edit.editInPopup(snip, "update") end
	end)
end

---@param files Scissors.snipFile[]
---@param formatter function(snipFile): string
---@param prompt string
---@param bodyPrefill string[] for the new snippet
function M.addSnippet(files, formatter, prompt, bodyPrefill)
	local backdropAugroup = require("scissors.backdrop").setup("DressingSelect")

	vim.ui.select(files, {
		prompt = prompt,
		format_item = formatter,
		kind = "nvim-scissors.fileSelect",
	}, function(snipFile)
		vim.api.nvim_del_augroup_by_id(backdropAugroup)
		if snipFile then edit.createNewSnipAndEdit(snipFile, bodyPrefill) end
	end)
end
--------------------------------------------------------------------------------
return M
