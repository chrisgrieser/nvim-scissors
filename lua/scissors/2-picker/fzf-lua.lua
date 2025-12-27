-- DOCS https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#-module
--------------------------------------------------------------------------------
local M = {}

local u = require("scissors.utils")
--------------------------------------------------------------------------------

--- an implementation of the fzf-lua previewer api which shows snippet bodies.
--- @class Snacks.FzfLuaSnippetPreviewer : fzf-lua.config.Previewer, fzf-lua.previewer.Builtin
--- @field super fzf-lua.previewer.Builtin the Builtin class
--- @see <https://github.com/ibhagwan/fzf-lua/wiki/Advanced#neovim-builtin-preview>
local SnippetPreviewer = require("fzf-lua.previewer.builtin").base:extend()

--- creates a new instance of the snippet previewer class.
--- part of fzf-lua's previewer api.
---@param o table
---@param opts table
---@return fzf-lua.previewer.Builtin
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
	vim.api.nvim_set_option_value('filetype', filetype, setOpts)
	vim.api.nvim_set_option_value('modifiable', false, setOpts)
	vim.defer_fn(function() u.tokenHighlight(tmpbuf) end, 1)

	self:set_preview_buf(tmpbuf)
	self.win:update_preview_scrollbar()
end

--- creates a function which fzf will use to populate the list of
--- available snippets.
---
--- when the function is called, it will populate a cache of
--- display names for each snippet. This cache is typically re-used
--- by the FzfLuaSnippetPreviewer.
---
--- @param snippets Scissors.SnippetObj
--- @return { [string]: Scissors.SnippetObj } snippetsByDisplayName
--- @return fun(cb: fzf-lua.fzfCb) setContents
local function createContentSetter(snippets)
	local snippetsByDisplayName = {}

	--- @param cb fzf-lua.fzfCb
	local function setContents(cb)
		local co = coroutine.running()
		local function resume() coroutine.resume(co) end

		for _, snip in ipairs(snippets) do
			local displayName = u.snipDisplayName(snip)

			snippetsByDisplayName[displayName] = snip
			cb(displayName, resume)
			coroutine.yield()
		end

		-- signal EOF to fzf and close the named pipe
		cb()
	end

	return snippetsByDisplayName, coroutine.wrap(setContents)
end

---@param snippets Scissors.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	local fzf = require('fzf-lua')
	local conf = require("scissors.config").config.snippetSelection.fzfLua

	local snippetsByDisplayName, setContents = createContentSetter(snippets)
	fzf.fzf_exec(setContents, {
		prompt = prompt,
		previewer = SnippetPreviewer,
		actions = {
			['default'] = function(selected, _)
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
