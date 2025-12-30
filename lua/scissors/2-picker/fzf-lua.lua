-- DOCS https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#-module
--------------------------------------------------------------------------------
local M = {}

local u = require("scissors.utils")
--------------------------------------------------------------------------------

--- an implementation of the
--- [fzf-lua](https://github.com/ibhagwan/fzf-lua/wiki/Advanced#neovim-builtin-preview)
--- previewer api which shows snippet bodies.
--- @class Scissors.FzfLuaSnippetPreviewer
--- @field super Scissors.FzfLua.Object the Builtin class
--- @field opts { [string]: unknown }
--- @field get_tmp_buffer fun(): integer
--- @field set_preview_buf fun(self: Scissors.FzfLuaSnippetPreviewer, buf: integer)
--- @field win Scissors.FzfLua.Win
local SnippetPreviewer = require("fzf-lua.previewer.builtin").base:extend()

--- creates a new instance of the snippet previewer class.
--- part of fzf-lua's previewer api.
---@param o table
---@param opts table
---@param fzf_win unknown
---@return Scissors.FzfLuaSnippetPreviewer
function SnippetPreviewer:new(o, opts, fzf_win)
	SnippetPreviewer.super.new(self, o, opts, fzf_win)
	setmetatable(self, SnippetPreviewer)
	return self
end

--- populates a temporary buffer with the contents of the given snippet's body.
--- the contents of the buffer are highlighted.
---@param displayName string of the snippet to preview
function SnippetPreviewer:populate_preview_buf(displayName)
	local snip = self.opts.scissorsSnippetsByDisplayName[displayName]

	local tmpbuf = self:get_tmp_buffer()
	vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, snip.body)

	--- @type vim.api.keyset.option
	local setOpts = { buf = tmpbuf }

	local filetype = snip.filetype == "all" and "text" or snip.filetype
	vim.api.nvim_set_option_value("filetype", filetype, setOpts)
	vim.api.nvim_set_option_value("modifiable", false, setOpts)
	vim.defer_fn(function() u.tokenHighlight(tmpbuf) end, 1)

	self:set_preview_buf(tmpbuf)
	self.win:update_preview_scrollbar()
end

---@param snippets Scissors.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	local fzf = require("fzf-lua")
	local conf = require("scissors.config").config.snippetSelection.fzfLua

	local snippetsByDisplayName = {}
	local snippetDislayNames = {}

	for i, snip in ipairs(snippets) do
		local displayName = u.snipDisplayName(snip)
		snippetsByDisplayName[displayName] = snip
		snippetDislayNames[i] = displayName
	end

	fzf.fzf_exec(snippetDislayNames, {
		prompt = prompt,
		previewer = SnippetPreviewer,
		actions = {
			["default"] = function(selected, _)
				local snip = snippetsByDisplayName[selected[1]]
				require("scissors.3-edit-popup").editInPopup(snip, "update")
			end,
		},

		-- this passes the scissors to the SnippetPreviewer.
		-- prefixed with "scissors" to hopefully prevent any future clashing
		scissorsSnippetsByDisplayName = snippetsByDisplayName,

		-- user config
		fzf_opts = conf.fzf_opts,
		silent = conf.silent,
		winopts = conf.winopts,
	})
end

--------------------------------------------------------------------------------
return M
