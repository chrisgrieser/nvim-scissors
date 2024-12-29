local M = {}
--------------------------------------------------------------------------------

---@param msg string
---@param level? "info"|"warn"|"error"|"debug"|"trace"
---@param opts? table
function M.notify(msg, level, opts)
	if not level then level = "info" end
	opts = opts or {}

	opts.title = "scissors"
	opts.icon = require("scissors.config").config.icons.scissors

	vim.notify(msg, vim.log.levels[level:upper()], opts)
end

---@param snip Scissors.SnippetObj|Scissors.VSCodeSnippet
---@return string snipName
function M.snipDisplayName(snip)
	local snipName = snip.prefix
	if type(snipName) == "table" then snipName = table.concat(snipName, " · ") end
	if #snipName > 50 then snipName = snipName:sub(1, 50) .. "…" end
	return snipName
end

---@nodiscard
---@param path string
---@return boolean
function M.fileExists(path) return vim.uv.fs_stat(path) ~= nil end

---DOCS https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax
---@param bufnr number
function M.tokenHighlight(bufnr)
	-- stylua: ignore
	local vars = { 
		-- https://code.visualstudio.com/docs/editor/userdefinedsnippets#_variables
		"TM_SELECTED_TEXT", "TM_CURRENT_LINE", "TM_CURRENT_WORD", "TM_LINE_INDEX", 
		"TM_LINE_NUMBER", "TM_FILENAME", "TM_FILENAME_BASE", "TM_DIRECTORY", 
		"TM_FILEPATH", "CLIPBOARD", "CURRENT_YEAR", "CURRENT_YEAR_SHORT",
		"CURRENT_MONTH", "CURRENT_MONTH_NAME", "CURRENT_MONTH_NAME_SHORT",
		"CURRENT_DATE", "CURRENT_DAY_NAME", "CURRENT_DAY_NAME_SHORT",
		"CURRENT_HOUR", "CURRENT_MINUTE", "CURRENT_SECOND", "CURRENT_SECONDS_UNIX", 
		"CURRENT_TIMEZONE_OFFSET", "RANDOM", "RANDOM_HEX", "UUID", "LINE_COMMENT", 
		"BLOCK_COMMENT_START", "BLOCK_COMMENT_END" 
	}

	vim.api.nvim_buf_call(bufnr, function()
		-- escaped dollar
		vim.fn.matchadd("@string.escape", [[\\\$]])

		-- do not highlights dollars signs after a backslash (negative lookbehind)
		-- https://neovim.io/doc/user/pattern.html#%2F%5C%40%3C%21
		local unescapedDollar = [[\(\\\)\@<!\$]]
		local hlgroup = "DiagnosticVirtualTextInfo"

		vim.fn.matchadd(hlgroup, unescapedDollar .. [[\d]]) -- tabstops
		vim.fn.matchadd(hlgroup, unescapedDollar .. [[{\d:.\{-}}]]) -- placeholders
		vim.fn.matchadd(hlgroup, unescapedDollar .. [[{\d|.\{-}|}]]) -- choice

		local bracedVars = unescapedDollar
			.. [[{\(]]
			.. table.concat(vars, [[\|]])
			.. [[\)]]
			.. [[\(.\{-}\)\?]] -- optional default value like `${TM_FILENAME:foobar}`
			.. "}"
		vim.fn.matchadd(hlgroup, bracedVars)

		local wordBoundariedVars = unescapedDollar .. [[\(]] .. table.concat(vars, [[\|]]) .. [[\)\>]]
		vim.fn.matchadd(hlgroup, wordBoundariedVars)
	end)
end

--------------------------------------------------------------------------------
return M
