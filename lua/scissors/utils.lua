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
	if type(snipName) == "table" then snipName = table.concat(snipName, " + ") end
	if #snipName > 50 then snipName = snipName:sub(1, 50) .. "…" end
	return snipName
end

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

--------------------------------------------------------------------------------
return M
