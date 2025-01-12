local M = {}
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@class Scissors.Config
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
			insertNextPlaceholder = "<C-p>", -- insert & normal mode
			showHelp = "?",
		},
	},
	telescope = {
		-- By default, the query only searches snippet prefixes. Set this to
		-- `true` to also search the body of the snippets.
		alsoSearchSnippetBody = false,

		-- accepts the common telescope picker config
		opts = {
			layout_strategy = "horizontal",
			layout_config = {
				horizontal = { width = 0.9 },
				preview_width = 0.6,
			},
		},
	},

	-- `none` writes as a minified json file using `vim.encode.json`.
	-- `yq`/`jq` ensure formatted & sorted json files, which is relevant when
	-- you version control your snippets. To use a custom formatter, set to a
	-- list of strings, which will then be passed to `vim.system()`.
	---@type "yq"|"jq"|"none"|string[]
	jsonFormatter = "none",

	backdrop = {
		enabled = true,
		blend = 50, -- between 0-100
	},
	icons = {
		scissors = "󰩫",
	},
}

--------------------------------------------------------------------------------

M.config = defaultConfig -- in case user does not call `setup`

---@param userConfig? Scissors.Config
function M.setupPlugin(userConfig)
	M.config = vim.tbl_deep_extend("force", defaultConfig, userConfig or {})

	-- `preview_width` is only supported by `horizontal` & `cursor` strategies, see #28
	local strategy = M.config.telescope.opts.layout_strategy
	if strategy ~= "horizontal" and strategy ~= "cursor" then
		M.config.telescope.opts.layout_config.preview_width = nil
	end

	-- normalizing relevant as it expands `~` to the home directory
	M.config.snippetDir = vim.fs.normalize(M.config.snippetDir)

	-- border `none` does not work with and title/footer used by this plugin
	if M.config.editSnippetPopup.border == "none" then
		local fallback = defaultConfig.editSnippetPopup.border
		M.config.editSnippetPopup.border = fallback
		local msg = ('Border type "none" is not supported, falling back to %q'):format(fallback)
		u.notify(msg, "warn")
	end
end

-- filetype used for the popup window of this plugin
M.scissorsFiletype = "scissors-snippet"

--------------------------------------------------------------------------------
return M
