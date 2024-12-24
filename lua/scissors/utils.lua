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

---@param lines string[]
---@return string[] dedentedLines
---@nodiscard
function M.dedentAndTrimBlanks(lines)
	-- remove leading and trailing blank lines
	while vim.trim(lines[1]) == "" do
		table.remove(lines, 1)
	end
	while vim.trim(lines[#lines]) == "" do
		table.remove(lines)
	end

	local smallestIndent = vim.iter(lines):fold(math.huge, function(acc, line)
		local indent = #line:match("^%s*")
		return math.min(acc, indent)
	end)
	local dedentedLines = vim.tbl_map(function(line) return line:sub(smallestIndent + 1) end, lines)
	return dedentedLines
end

---DOCS https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax
---@param bufnr number
function M.tokenHighlight(bufnr)
	local vars = require("scissors.vscode-format.snippet-variables").vars

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
