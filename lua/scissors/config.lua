local M = {}
--------------------------------------------------------------------------------

---@class (exact) pluginConfig
---@field snippetDir string
---@field editSnippetPopup { height: number, width: number, border: string, keymaps: popupKeymaps }
---@field jsonFormatter "yq"|"jq"|"none"
---@field autoReload boolean

---@class (exact) popupKeymaps
---@field cancel string
---@field saveChanges string
---@field delete string
---@field openInFile string

---@type pluginConfig
local defaultConfig = {
	snippetDir = vim.fn.stdpath("config") .. "/snippets",
	editSnippetPopup = {
		height = 0.4, -- between 0-1
		width = 0.6,
		border = "rounded",
		keymaps = {
			cancel = "q",
			saveChanges = "<CR>", -- normal mode
			delete = "<C-BS>",
			openInFile = "<C-o>",
		},
	},
	-- `none` writes as a minified json file using `:h vim.encode.json`.
	-- `yq` and `jq` ensure formatted & sorted json files, which is relevant when
	-- you are version control your snippets.
	jsonFormatter = "none", -- "yq"|"jq"|"none"

	-- on adding/editing a snippet, reload the snippet file. Currently only
	-- supports LuaSnip (PRs welcome)
	autoReload = true,
}

--------------------------------------------------------------------------------

M.config = defaultConfig -- in case user does not call `setup`

---@param userConfig pluginConfig
function M.setupPlugin(userConfig)
	M.config = vim.tbl_deep_extend("force", defaultConfig, userConfig)
end

--------------------------------------------------------------------------------
return M
