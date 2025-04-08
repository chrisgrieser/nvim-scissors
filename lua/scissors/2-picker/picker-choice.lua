local M = {}
--------------------------------------------------------------------------------

---@param allSnippets Scissors.SnippetObj[]
function M.selectSnippet(allSnippets)
	local icon = require("scissors.config").config.icons.scissors
	local prompt = vim.trim(icon .. " Select Snippet: ")
	local picker = require("scissors.config").config.snippetSelection.picker
	local hasTelescope, _ = pcall(require, "telescope")
	local hasSnacks, _ = pcall(require, "snacks")

	if picker == "telescope" or (picker == "auto" and hasTelescope) then
		require("scissors.2-picker.telescope").selectSnippet(allSnippets, prompt)
	elseif picker == "snacks" or (picker == "auto" and hasSnacks) then
		require("scissors.2-picker.snacks").selectSnippet(allSnippets, prompt)
	else
		require("scissors.2-picker.vim-ui-select").selectSnippet(allSnippets, prompt)
	end
end

--------------------------------------------------------------------------------
return M
