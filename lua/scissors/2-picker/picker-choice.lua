local M = {}
--------------------------------------------------------------------------------

---@param allSnippets Scissors.SnippetObj[]
function M.selectSnippet(allSnippets)
	local icon = require("scissors.config").config.icons.scissors
	local prompt = vim.trim(icon .. " Select Snippet: ")

	-- INFO not using ternary to pass variable into `require`, since that
	-- prevents the LSP from picking up references
	local hasTelescope, _ = pcall(require, "telescope")
	local hasSnacks, _ = pcall(require, "snacks")
	if hasTelescope then
		require("scissors.2-picker.telescope").selectSnippet(allSnippets, prompt)
	elseif hasSnacks then
		require("scissors.2-picker.snacks").selectSnippet(allSnippets, prompt)
	else
		require("scissors.2-picker.vim-ui-select").selectSnippet(allSnippets, prompt)
	end
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
	local prompt = vim.trim(icon .. " Select file for new snippet: ")

	local hasTelescope, _ = pcall(require, "telescope")
	if hasTelescope then
		-- stylua: ignore
		require("scissors.2-picker.telescope").addSnippet(allSnipFiles, fileDisplay, prompt, bodyPrefill)
	else
		-- stylua: ignore
		require("scissors.2-picker.vim-ui-select").addSnippet(allSnipFiles, fileDisplay, prompt, bodyPrefill)
	end
end
--------------------------------------------------------------------------------
return M
