local M = {}
local u = require("scissors.utils")
--------------------------------------------------------------------------------

local hasNotifiedOnRestartRequirement = false

---@param path string
function M.reloadSnippetFile(path)
	local luasnipInstalled, luasnipLoaders = pcall(require, "luasnip.loaders")
	local nvimSnippetsInstalled, snippetUtils = pcall(require, "snippets.utils")

	-- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
	if luasnipInstalled then
		luasnipLoaders.reload_file(path)

	-- https://github.com/garymjr/nvim-snippets/commit/754528d10277758ae3ff62dd8a2d0e44425b606f
	elseif nvimSnippetsInstalled then
		snippetUtils.reload_file(path, true)

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
