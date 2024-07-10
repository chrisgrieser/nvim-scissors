local M = {}
local u = require("scissors.utils")
--------------------------------------------------------------------------------

local hasNotifiedOnRestartRequirement = false

---@param path string
---@param fileIsNew? boolean
function M.reloadSnippetFile(path, fileIsNew)
	-- GUARD
	if fileIsNew then
		local name = vim.fs.basename(path)
		local msg = ("%q is a new file and thus cannot be hot-reloaded. "):format(name)
			.. "Please restart nvim for this change to take effect."
		u.notify(msg)
		return
	end

	local luasnipInstalled, luasnipLoaders = pcall(require, "luasnip.loaders")
	local nvimSnippetsInstalled, snippetUtils = pcall(require, "snippets.utils")
	local vimVsnipInstalled = vim.g.loaded_vsnip ~= nil -- https://github.com/hrsh7th/vim-vsnip/blob/master/plugin/vsnip.vim#L4C5-L4C17

	-- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
	if luasnipInstalled then
		luasnipLoaders.reload_file(path)

	-- undocumented, https://github.com/garymjr/nvim-snippets/blob/main/lua/snippets/utils/init.lua#L161-L178
	elseif nvimSnippetsInstalled then
		snippetUtils.reload_file(path, true)

		-- HACK fix nvim-snip not correctly reloading https://github.com/garymjr/nvim-snippets/issues/47
		local _, nvimSnip = pcall(require, "snippets")
		if nvimSnip then nvimSnip.clear_cache() end

	-- https://github.com/hrsh7th/vim-vsnip/blob/02a8e79295c9733434aab4e0e2b8c4b7cea9f3a9/autoload/vsnip/source/vscode.vim#L7
	elseif vimVsnipInstalled then
		vim.fn["vsnip#source#vscode#refresh"](path)

	-- notify
	elseif not hasNotifiedOnRestartRequirement then
		local msg = "Restart nvim for changes to take effect.\n"
			.. "(Please open an issue to add hot-reloading support for your snippet plugin.)"
		u.notify(msg, "info")
		hasNotifiedOnRestartRequirement = true
	end
end

--------------------------------------------------------------------------------
return M
