local M = {}
local u = require("scissors.utils")
--------------------------------------------------------------------------------

local fallbackBorder = "rounded"

---@return string
local function getBorder()
	local hasWinborder, winborder = pcall(function() return vim.o.winborder end)
	if not hasWinborder or winborder == "" or winborder == "none" then return fallbackBorder end
	return winborder
end

--------------------------------------------------------------------------------

---@class Scissors.Config
local defaultConfig = {
	snippetDir = vim.fn.stdpath("config") .. "/snippets",
	editSnippetPopup = {
		height = 0.4, -- relative to the window, between 0-1
		width = 0.6,
		border = getBorder(), -- `vim.o.winborder` on nvim 0.11, otherwise "rounded"
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
	snippetSelection = {
		picker = "auto", ---@type "auto"|"telescope"|"snacks"|"vim.ui.select"

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

		-- `snacks` picker configurable via snacks config,
		-- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md
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

	-- DEPRECATION (2025-04-08)
	---@diagnostic disable: undefined-field
	if M.config.telescope then
		local msg =
			"The nvim-scissors config `telescope` is deprecated. Use `snippetSelection.telescope` instead."
		u.notify(msg, "warn")
		M.config.snippetSelection.telescope = M.config.telescope
	end
	---@diagnostic enable: undefined-field

	-- `preview_width` is only supported by `horizontal` & `cursor` strategies, see #28
	local strategy = M.config.snippetSelection.telescope.opts.layout_strategy
	if strategy ~= "horizontal" and strategy ~= "cursor" then
		M.config.snippetSelection.telescope.opts.layout_config.preview_width = nil
	end

	-- normalizing relevant as it expands `~` to the home directory
	M.config.snippetDir = vim.fs.normalize(M.config.snippetDir)

	-- border `none` does not work with and title/footer used by this plugin
	if M.config.editSnippetPopup.border == "none" or M.config.editSnippetPopup.border == "" then
		M.config.editSnippetPopup.border = fallbackBorder
		local msg = ('Border type "none" is not supported, falling back to %q'):format(fallbackBorder)
		u.notify(msg, "warn")
	end
end

-- filetype used for the popup window of this plugin
M.scissorsFiletype = "scissors-snippet"

--------------------------------------------------------------------------------
return M
