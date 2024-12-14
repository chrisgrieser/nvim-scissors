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
		},
	},
	telescope = {
		-- By default, the query only searches snippet prefixes. Set this to
		-- `true` to also search the body of the snippets.
		alsoSearchSnippetBody = false,

		-- accepts the common telescope picker config
		opts = {
			layout_strategies = "horizontal",
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

	-- normalizing e.g. expands `~` in provided snippetDir
	M.config.snippetDir = vim.fs.normalize(M.config.snippetDir)

	-- DEPRECATION of `insertNextToken`
	if M.config.editSnippetPopup.keymaps.insertNextToken then ---@diagnostic disable-line: undefined-field
		M.config.editSnippetPopup.keymaps.insertNextPlaceholder =
			M.config.editSnippetPopup.keymaps.insertNextToken ---@diagnostic disable-line: undefined-field
		local msg = "The `insertNextToken` keymap is deprecated, use `insertNextPlaceholder` instead."
		u.notify(msg, "warn")
	end

	-- DEPRECATION of `jumpBetweenBodyAndPrefix`
	if M.config.editSnippetPopup.keymaps.jumpBetweenBodyAndPrefix then ---@diagnostic disable-line: undefined-field
		local msg = "The `jumpBetweenBodyAndPrefix` keymap has been removed. "
			.. "You can now create a filetype-specific for custom keymaps using "
			.. "the filetype `scissors-snippet`."
		u.notify(msg, "warn")
	end

	-- VALIDATE border `none` does not work with and title/footer used by this plugin
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
