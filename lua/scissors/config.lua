local M = {}
--------------------------------------------------------------------------------

---@class (exact) pluginConfig
---@field snippetDir string
---@field editSnippetPopup { height: number, width: number, border: string, keymaps: popupKeymaps }
---@field jsonFormatter "yq"|"jq"|"none"

---@class (exact) popupKeymaps
---@field cancel string
---@field saveChanges string
---@field deleteSnippet string
---@field openInFile string
---@field insertNextToken string
---@field goBackToSearch string
---@field jumpBetweenBodyAndPrefix string

---@type pluginConfig
local defaultConfig = {
	snippetDir = vim.fn.stdpath("config") .. "/snippets",
	editSnippetPopup = {
		height = 0.4, -- relative to the window, between 0-1
		width = 0.6,
		border = "rounded",
		keymaps = {
			cancel = "q",
			saveChanges = "<CR>", -- alternatively, can also use `:w`
			goBackToSearch = "<BS>",
			deleteSnippet = "<C-BS>",
			openInFile = "<C-o>",
			insertNextToken = "<C-t>", -- insert & normal mode
			jumpBetweenBodyAndPrefix = "<C-Tab>", -- insert & normal mode
		},
	},
	-- `none` writes as a minified json file using `:h vim.encode.json`.
	-- `yq` and `jq` ensure formatted & sorted json files, which is relevant when
	-- you are version control your snippets.
	jsonFormatter = "none", -- "yq"|"jq"|"none"
}

--------------------------------------------------------------------------------

M.config = defaultConfig -- in case user does not call `setup`

---@param userConfig pluginConfig
function M.setupPlugin(userConfig)
	-- normalizing e.g. expands `~` in provided snippetDir
	if userConfig.snippetDir then userConfig.snippetDir = vim.fs.normalize(userConfig.snippetDir) end

	---@deprecated keymap.delete
	if userConfig.editSnippetPopup and userConfig.editSnippetPopup.keymaps and userConfig.editSnippetPopup.keymaps.delete then ---@diagnostic disable-line: undefined-field
		local notify = require("scissors.utils").notify
		notify("`keymap.delete` is deprecated. Use `keymap.deleteSnippet instead.", "warn")
		userConfig.editSnippetPopup.keymaps.deleteSnippet = userConfig.editSnippetPopup.keymaps.delete ---@diagnostic disable-line: undefined-field
	end

	M.config = vim.tbl_deep_extend("force", defaultConfig, userConfig)
end

--------------------------------------------------------------------------------
return M
