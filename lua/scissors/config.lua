local M = {}
--------------------------------------------------------------------------------

---@class (exact) pluginConfig
---@field snippetDir string
---@field editSnippetPopup { height: number, width: number, border: string, keymaps: popupKeymaps }
---@field telescope telescopeConfig
---@field jsonFormatter "yq"|"jq"|"none"

---@class (exact) popupKeymaps
---@field cancel string
---@field saveChanges string
---@field deleteSnippet string
---@field duplicateSnippet string
---@field openInFile string
---@field insertNextToken string
---@field goBackToSearch string
---@field jumpBetweenBodyAndPrefix string

---@class (exact) telescopeConfig
---@field alsoSearchSnippetBody boolean

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
			duplicateSnippet = "<C-d>",
			openInFile = "<C-o>",
			insertNextToken = "<C-t>", -- insert & normal mode
			jumpBetweenBodyAndPrefix = "<C-Tab>", -- insert & normal mode
		},
	},
	telescope = {
		-- By default, the query only searches snippet prefixes. Set this to
		-- `true` to also search the body of the snippets.
		alsoSearchSnippetBody = false,
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

	M.config = vim.tbl_deep_extend("force", defaultConfig, userConfig)
end

--------------------------------------------------------------------------------
return M
