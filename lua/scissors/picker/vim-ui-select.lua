local M = {}

local edit = require("scissors.edit-popup")
local u = require("scissors.utils")
local backdropAugroup
--------------------------------------------------------------------------------

local function setupBackdrop()
	---This only affects the builtin `select` from dressing.nvim. The autocmd id is
	---saved to be able to remove it, in case it was not used, e.g. due to the user
	---using selector-provider such as `fzf-lua`.
	backdropAugroup = vim.api.nvim_create_augroup("nvim-scissors.backdrop", {})

	vim.api.nvim_create_autocmd("FileType", {
		group = backdropAugroup,
		once = true,
		pattern = "DressingSelect",
		callback = function(ctx) require("scissors.backdrop").new(ctx.buf) end,
	})
end

---@param snippets Scissors.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	setupBackdrop()
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
	setupBackdrop()
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
