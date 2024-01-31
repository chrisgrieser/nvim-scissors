local config = require("scissors.config").config
local convert = require("scissors.vscode-format.convert-object")
local rw = require("scissors.vscode-format.read-write")
local u = require("scissors.utils")

local M = {}
local a = vim.api
--------------------------------------------------------------------------------

---@class (exact) extMarkInfo
---@field bufnr number
---@field ns number
---@field id number

---INFO the extmark representing the horizontal divider between prefix and body
---also acts as method to determine the number of prefixes. If the user has
---inserted/deleted a line, this is considered a change in number of prefixes
---@param prefixBodySep extMarkInfo
---@return number newCount
---@nodiscard
local function getPrefixCount(prefixBodySep)
	local extM = prefixBodySep
	local newCount = a.nvim_buf_get_extmark_by_id(extM.bufnr, extM.ns, extM.id, {})[1] + 1
	return newCount
end

---@param bufnr number
---@param winnr number
---@param mode "new"|"update"
---@param snip SnippetObj
---@param prefixBodySep extMarkInfo
local function setupPopupKeymaps(bufnr, winnr, mode, snip, prefixBodySep)
	local keymap = vim.keymap.set
	local opts = { buffer = bufnr, nowait = true, silent = true }
	local mappings = config.editSnippetPopup.keymaps
	local function closePopup()
		if a.nvim_win_is_valid(winnr) then a.nvim_win_close(winnr, true) end
		if a.nvim_buf_is_valid(bufnr) then a.nvim_buf_delete(bufnr, { force = true }) end
	end
	local function confirmChanges()
		local editedLines = a.nvim_buf_get_lines(bufnr, 0, -1, false)
		local newPrefixCount = getPrefixCount(prefixBodySep)
		convert.updateSnippetFile(snip, editedLines, newPrefixCount)
		closePopup()
	end

	keymap("n", mappings.cancel, closePopup, opts)

	-- also close the popup on leaving buffer, ensures there is not leftover
	-- buffer when user closes popup in a different way, such as `:close`.
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = bufnr,
		once = true,
		callback = closePopup,
	})

	keymap("n", mappings.saveChanges, confirmChanges, opts)
	-- so people in the habit of saving via `:w` do not get an error
	vim.cmd.cnoreabbrev("<buffer> w ScissorsSave")
	vim.cmd.cnoreabbrev("<buffer> write ScissorsSave")
	vim.api.nvim_buf_create_user_command(bufnr, "ScissorsSave", confirmChanges, {})

	keymap("n", mappings.deleteSnippet, function()
		if mode == "new" then
			u.notify("Cannot delete a snippet that has not been saved yet.", "warn")
			return
		end
		rw.deleteSnippet(snip)
		closePopup()
	end, opts)

	keymap("n", mappings.duplicateSnippet, function()
		if mode == "new" then
			u.notify("Cannot duplicate a snippet that has not been saved yet.", "warn")
			return
		end
		u.notify(("Duplicating snippet %q"):format(u.snipDisplayName(snip)))
		local currentBody = a.nvim_buf_get_lines(bufnr, getPrefixCount(prefixBodySep), -1, false)
		closePopup()
		local snipFile = { path = snip.fullPath, ft = snip.filetype } ---@type snipFile
		M.createNewSnipAndEdit(snipFile, currentBody)
	end, opts)

	keymap("n", mappings.openInFile, function()
		closePopup()
		local locationInFile = snip.originalKey:gsub(" ", [[\ ]])
		vim.cmd(("edit +/%q %s"):format(locationInFile, snip.fullPath))
	end, opts)

	keymap({ "n", "i" }, mappings.insertNextToken, function()
		local bufText = table.concat(a.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
		local numbers = {}
		local tokenPattern = "${?(%d+)" -- match `$1`, `${2:word}`, or `${3|word|}`
		for token in bufText:gmatch(tokenPattern) do
			table.insert(numbers, tonumber(token))
		end
		local highestToken = #numbers > 0 and math.max(unpack(numbers)) or 0

		local insertStr = ("${%s:}"):format(highestToken + 1)
		local row, col = unpack(a.nvim_win_get_cursor(0))
		a.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { insertStr })

		-- move cursor
		a.nvim_win_set_cursor(0, { row, col + #insertStr - 1 })
		vim.cmd.startinsert()
	end, opts)

	keymap("n", mappings.goBackToSearch, function()
		closePopup()
		if mode == "new" then
			require("scissors").addNewSnippet()
		elseif mode == "update" then
			require("scissors").editSnippet()
		end
	end, opts)

	keymap({ "i", "n" }, mappings.jumpBetweenBodyAndPrefix, function()
		local prefixCount = getPrefixCount(prefixBodySep)
		local currentLine = a.nvim_win_get_cursor(0)[1]
		local isInBody = currentLine > prefixCount
		local moveToLine = isInBody and 1 or currentLine + 1
		a.nvim_win_set_cursor(winnr, { moveToLine, 0 })
	end, opts)

	-- HACK workaround to deal with prefix-deletion on last prefix line (see issue #6)
	-- (no other configuration of the virtual line fixes this, could be nvim-bug?)
	keymap("n", "dd", function()
		local prefixCount = getPrefixCount(prefixBodySep)
		local currentLine = a.nvim_win_get_cursor(0)[1]
		if currentLine == prefixCount then return "^DkJ" end
		return "dd"
	end, vim.tbl_extend("keep", opts, { expr = true }))
end

--------------------------------------------------------------------------------

---@param snipFile snipFile
---@param bodyPrefill string[]
function M.createNewSnipAndEdit(snipFile, bodyPrefill)
	local snip = {
		prefix = { "" },
		body = bodyPrefill,
		fullPath = snipFile.path,
		filetype = snipFile.ft,
	}
	M.editInPopup(snip, "new")
end

---@param snip SnippetObj
---@param mode "new"|"update"
function M.editInPopup(snip, mode)
	local conf = config.editSnippetPopup
	local ns = a.nvim_create_namespace("nvim-scissors-editing")

	-- snippet properties
	local copy = vim.deepcopy(snip.prefix) -- copy since `list_extend` mutates destination
	local lines = vim.list_extend(copy, snip.body)
	local nameOfSnippetFile = vim.fs.basename(snip.fullPath)

	local bufName, winTitle
	if mode == "update" then
		bufName = u.snipDisplayName(snip)
		winTitle = (" Editing %q [%s] "):format(bufName, nameOfSnippetFile)
	else
		bufName = "New Snippet"
		winTitle = (" New Snippet in %q "):format(nameOfSnippetFile)
	end

	-- create buffer and window
	local bufnr = a.nvim_create_buf(false, true)
	a.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	a.nvim_buf_set_name(bufnr, bufName)
	a.nvim_buf_set_option(bufnr, "buftype", "nofile")
	a.nvim_buf_set_option(bufnr, "filetype", snip.filetype)

	local winnr = a.nvim_open_win(bufnr, true, {
		relative = "win",
		title = winTitle,
		title_pos = "center",
		border = conf.border,
		-- centered window
		width = math.floor(conf.width * a.nvim_win_get_width(0)),
		height = math.floor(conf.height * a.nvim_win_get_height(0)),
		row = math.floor((1 - conf.height) * a.nvim_win_get_height(0) / 2),
		col = math.floor((1 - conf.width) * a.nvim_win_get_width(0) / 2),
		zindex = 1, -- below nvim-notify floats
	})
	a.nvim_win_set_option(winnr, "signcolumn", "no")
	a.nvim_win_set_option(winnr, "list", true)
	a.nvim_win_set_option(winnr, "listchars", vim.wo.listchars .. ",trail:·")

	-- move cursor, highlight cursor positions
	if mode == "new" then
		vim.defer_fn(vim.cmd.startinsert, 1) -- for whatever reason needs to be deferred to work reliably
	elseif mode == "update" then
		local firstLineOfBody = #snip.prefix + 1
		pcall(a.nvim_win_set_cursor, winnr, { firstLineOfBody, 0 })
	end
	u.tokenHighlight(bufnr)

	-- PREFIX-BODY-SEPARATOR
	-- (INFO its position determines number of prefixes)
	local winWidth = a.nvim_win_get_width(winnr)
	local prefixBodySep = { bufnr = bufnr, ns = ns, id = -1 } ---@type extMarkInfo
	prefixBodySep.id = a.nvim_buf_set_extmark(bufnr, ns, #snip.prefix - 1, 0, {
		virt_lines = {
			{ { ("═"):rep(winWidth), "FloatBorder" } },
		},
		virt_lines_leftcol = true,
		-- "above line n" instead of "below line n-1" changes where new lines
		-- occur when creating them. The latter appears to be more intuitive.
		virt_lines_above = false,
	})

	-- continuously update highlight prefix lines and add label
	local labelExtMarkIds = {} ---@type number[]
	local function updatePrefixLabel(newPrefixCount) ---@param newPrefixCount number
		for _, label in pairs(labelExtMarkIds) do
			a.nvim_buf_del_extmark(bufnr, ns, label)
		end
		for i = 1, newPrefixCount do
			local ln = i - 1
			local label = newPrefixCount == 1 and "Prefix" or "Prefix #" .. i
			a.nvim_buf_add_highlight(bufnr, ns, "DiagnosticVirtualTextHint", ln, 0, -1)
			local id = a.nvim_buf_set_extmark(bufnr, ns, ln, 0, {
				virt_text = { { label, "Todo" } },
				virt_text_pos = "right_align",
			})
			table.insert(labelExtMarkIds, id)
		end
	end
	updatePrefixLabel(#snip.prefix) -- initialize
	-- update in case prefix count changes due to user input
	a.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = bufnr,
		callback = function()
			local newPrefixCount = getPrefixCount(prefixBodySep)
			updatePrefixLabel(newPrefixCount)
		end,
	})

	-- keymaps
	setupPopupKeymaps(bufnr, winnr, mode, snip, prefixBodySep)
end

--------------------------------------------------------------------------------
return M
