local M = {}
--------------------------------------------------------------------------------

---@param msg string
---@param level? "info"|"warn"|"error"|"debug"|"trace"
function M.notify(msg, level)
	if not level then level = "info" end
	vim.notify(msg, vim.log.levels[level:upper()], { title = "nvim-scissors" })
end

---@param snip SnippetObj|VSCodeSnippet
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

---@param lines string[]
---@return string[] dedentedLines
function M.dedent(lines)
	local indentAmounts = vim.tbl_map(function(line) return #(line:match("^%s*")) end, lines)
	local smallestIndent = math.min(unpack(indentAmounts))
	local dedentedLines = vim.tbl_map(function(line) return line:sub(smallestIndent + 1) end, lines)
	return dedentedLines
end

function M.leaveVisualMode()
	local escKey = vim.api.nvim_replace_termcodes("<Esc>", false, true, true)
	vim.api.nvim_feedkeys(escKey, "nx", false)
end

---DOCS https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax
---@param bufnr number
function M.tokenHighlight(bufnr)
	local hlgroup = "DiagnosticVirtualTextInfo"
	vim.api.nvim_buf_call(bufnr, function()
		-- do not highlights dollars signs after a backslash (negative lookbehind)
		-- https://neovim.io/doc/user/pattern.html#%2F%5C%40%3C%21
		local unescapedDollarSign = [[\(\\\)\@<!\$]]

		vim.fn.matchadd(hlgroup, unescapedDollarSign .. [[\d]]) -- tabstops
		vim.fn.matchadd(hlgroup, unescapedDollarSign .. [[{\d:.\{-}}]]) -- placeholders
		vim.fn.matchadd(hlgroup, unescapedDollarSign .. [[{\d|.\{-}|}]]) -- choice

		local vars = {
			"TM_SELECTED_TEXT",
			"TM_CURRENT_LINE",
			"TM_CURRENT_WORD",
			"TM_LINE_INDEX",
			"TM_LINE_NUMBER",
			"TM_FILENAME",
			"TM_FILENAME_BASE",
			"TM_DIRECTORY",
			"TM_FILEPATH",
			"CLIPBOARD",
			"CURRENT_YEAR",
			"CURRENT_YEAR_SHORT",
			"CURRENT_MONTH",
			"CURRENT_MONTH_NAME",
			"CURRENT_MONTH_NAME_SHORT",
			"CURRENT_DATE",
			"CURRENT_DAY_NAME",
			"CURRENT_DAY_NAME_SHORT",
			"CURRENT_HOUR",
			"CURRENT_MINUTE",
			"CURRENT_SECOND",
			"CURRENT_SECONDS_UNIX",
			"CURRENT_TIMEZONE_OFFSET",
			"RANDOM",
			"RANDOM_HEX",
			"UUID",
			"LINE_COMMENT",
			"BLOCK_COMMENT_START",
			"BLOCK_COMMENT_END",
		}
		local bracedVars = vim.tbl_map(function(var) return "{" .. var .. "}" end, vars)
		local wordBoundaried = vim.tbl_map(function(var) return [[\<]] .. var .. [[\>]] end, vars)
		local both = vim.list_extend(bracedVars, wordBoundaried)

		local varsStr = unescapedDollarSign .. [[\(]] .. table.concat(both, [[\|]]) .. [[\)]]
		vim.fn.matchadd(hlgroup, varsStr)
	end)
end

--------------------------------------------------------------------------------
return M
