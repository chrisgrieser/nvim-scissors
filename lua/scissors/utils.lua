local M = {}
--------------------------------------------------------------------------------

---@param msg string
---@param level? "info"|"warn"|"error"|"debug"|"trace"
function M.notify(msg, level)
	if not level then level = "info" end
	vim.notify(msg, vim.log.levels[level:upper()], { title = "nvim-scissors" })
end

---@param snip SnippetObj
---@return string snipName
function M.snipDisplayName(snip)
	local snipName = table.concat(snip.prefix, " + ")
	if #snipName > 50 then snipName = snipName:sub(1, 50) .. "…" end
	return snipName
end

--------------------------------------------------------------------------------
return M
