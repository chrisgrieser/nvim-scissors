local M = {}
--------------------------------------------------------------------------------

---@class Scissors.Config
local defaultConfig = {
	snippetDir = vim.fn.stdpath("config") .. "/snippets",
	editSnippetPopup = {
		height = 0.4, -- relative to the window, between 0-1
		width = 0.6,
		border = vim.o.winborder,
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
		picker = "auto", ---@type "auto"|"fzf-lua"|"telescope"|"snacks"|"vim.ui.select"

		--- @module 'fzf-lua'
		fzfLua = {
			-- same format as fzf_opts in `:h fzf-lua-customization`
			fzf_opts = {},

			-- suppress warnings from fzf-lua.
			-- This is true by default, since commonly-used fzf-lua presets
			-- create warnings due to border settings.
			silent = true,

			-- same format as winopts in `:h fzf-lua-customization`
			winopts = {
				preview = {
					hidden = false,
				},
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

		-- the `snacks` picker configurable via snacks config,
		-- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md
	},
	jsonFormatOpts = { -- formatting of snippet files, passed to `:h vim.json.encode()`
		sort_keys = true,
		indent = "  ",
	},
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
	local strategy = M.config.snippetSelection.telescope.opts.layout_strategy
	if strategy ~= "horizontal" and strategy ~= "cursor" then
		M.config.snippetSelection.telescope.opts.layout_config.preview_width = nil
	end

	-- DEPRECATION 2025-12-29
	if M.config.jsonFormatter then ---@diagnostic disable-line: undefined-field
		local msg = {
			"nvim-scissors now uses the new `vim.json.encode` capabilities to format your snippets.",
			"The config `jsonFormatter` is thus not used anymore, and should be removed from your config.",
			"(jq/yq are thus also no longer needed.)",
			"",
			"Use the new `jsonFormatOpts` config to control how your snippets are formatted via `vim.json.encode` or to disable formatting.",
		}
		require("scissors.utils").notify(table.concat(msg, "\n"), "warn")
	end

	-- normalizing relevant as it expands `~` to the home directory
	M.config.snippetDir = vim.fs.normalize(M.config.snippetDir)

	-- border `none` does not work with and title/footer used by this plugin
	if M.config.editSnippetPopup.border == "none" or M.config.editSnippetPopup.border == "" then
		M.config.editSnippetPopup.border = "single"
	end
end

-- filetype used for the popup window of this plugin
M.scissorsFiletype = "scissors-snippet"

--------------------------------------------------------------------------------
return M
