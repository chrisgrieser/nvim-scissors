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

	local success = false
	local errorMsg = ""

	local luasnipInstalled, luasnipLoaders = pcall(require, "luasnip.loaders")
	local nvimSnippetsInstalled, snippetUtils = pcall(require, "snippets.utils")
	local vimVsnipInstalled = vim.g.loaded_vsnip ~= nil -- https://github.com/hrsh7th/vim-vsnip/blob/master/plugin/vsnip.vim#L4C5-L4C17
	local blinkCmpInstalled, blinkCmp = pcall(require, "blink.cmp")
	local basicsLsInstalled = vim.fn.executable("basics-language-server") == 1

	-- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
	if luasnipInstalled then
		success, errorMsg = pcall(luasnipLoaders.reload_file, path)

	-- undocumented, https://github.com/garymjr/nvim-snippets/blob/main/lua/snippets/utils/init.lua#L161-L178
	elseif nvimSnippetsInstalled then
		success, errorMsg = pcall(snippetUtils.reload_file, path, true)

	-- https://github.com/hrsh7th/vim-vsnip/blob/02a8e79295c9733434aab4e0e2b8c4b7cea9f3a9/autoload/vsnip/source/vscode.vim#L7
	elseif vimVsnipInstalled then
		success, errorMsg = pcall(vim.fn["vsnip#source#vscode#refresh"], path)

	-- https://github.com/antonk52/basics-language-server/issues/1
	elseif basicsLsInstalled then
		if vim.cmd.LspRestart == nil then
			local msg = "Hot-reloading for `basics_ls` requires `nvim-lspconfig`. Restart nvim manually for changes to take effect."
			u.notify(msg, "warn")
			return
		end
		success, errorMsg = pcall(vim.cmd.LspRestart, "basics_ls")

	-- https://github.com/Saghen/blink.cmp/issues/28#issuecomment-2415664831
	elseif blinkCmpInstalled then
		success, errorMsg = pcall(blinkCmp.sources.reload)

	-- notify
	elseif not hasNotifiedOnRestartRequirement then
		local msg = "Your snippet plugin does not support hot-reloading. Restart nvim for changes to take effect."
		u.notify(msg, "info")
		hasNotifiedOnRestartRequirement = true
		return
	end

	if not success then
		local msg = ("Failed to hot-reload snippet file: %q\n\n."):format(errorMsg)
			.. "Please restart nvim for changes to take effect. "
			.. "If this issue keeps occurring, create a bug report at your snippet plugin's repo."
		u.notify(msg, "warn")
	end
end

--------------------------------------------------------------------------------
return M
