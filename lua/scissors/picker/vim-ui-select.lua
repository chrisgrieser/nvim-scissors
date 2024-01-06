local M = {}

local edit = require("scissors.edit-popup")
--------------------------------------------------------------------------------

---@param snippets SnippetObj[] entries
---@param formatter function(SnippetObj): string formats SnippetObj into display text
---@param prompt string
function M.selectSnippet(snippets, formatter, prompt)
	vim.ui.select(snippets, {
		prompt = prompt,
		format_item = formatter,
		kind = "nvim-scissors.snippetSearch",
	}, function(snip)
		if not snip then return end
		edit.editInPopup(snip, "update")
	end)
end

---@param files snipFile[]
---@param formatter function(snipFile): string
---@param prompt string
---@param bodyPrefill string[] for the new snippet
function M.addSnippet(files, formatter, prompt, bodyPrefill)
	vim.ui.select(files, {
		prompt = prompt,
		format_item = formatter,
		kind = "nvim-scissors.fileSelect",
	}, function(snipFile)
		if not snipFile then return end
		edit.createNewSnipAndEdit(snipFile, bodyPrefill)
	end)
end
--------------------------------------------------------------------------------
return M
