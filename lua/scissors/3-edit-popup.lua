local M = {}

local convert = require("scissors.vscode-format.convert-object")
local rw = require("scissors.vscode-format.read-write")
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@class (exact) Scissors.extMarkInfo
---@field bufnr number
---@field ns number
---@field id number

---INFO the extmark representing the horizontal divider between prefix and body
---also acts as method to determine the number of prefixes. If the user has
---inserted/deleted a line, this is considered a change in number of prefixes
---@param prefixBodySep Scissors.extMarkInfo
---@return number newCount
---@nodiscard
local function getPrefixCount(prefixBodySep)
	local extM = prefixBodySep
	local newCount = vim.api.nvim_buf_get_extmark_by_id(extM.bufnr, extM.ns, extM.id, {})[1] + 1
	return newCount
end

-- continuously update highlight prefix lines and add label
---@param newPrefixCount number
---@param bufnr number
local function updatePrefixLabel(newPrefixCount, bufnr)
	local prefixLabelNs = vim.api.nvim_create_namespace("nvim-scissors-prefix-label")
	vim.api.nvim_buf_clear_namespace(bufnr, prefixLabelNs, 0, -1)
	for i = 1, newPrefixCount do
		local label = newPrefixCount == 1 and "Prefix" or "Prefix #" .. i
		vim.api.nvim_buf_set_extmark(bufnr, prefixLabelNs, i - 1, 0, {
			virt_text = { { label, "Todo" } },
			virt_text_pos = "right_align",
			line_hl_group = "DiagnosticVirtualTextHint",
		})
	end
end

---@param bufnr number
---@param winnr number
---@param mode "new"|"update"
---@param snip Scissors.SnippetObj
---@param prefixBodySep Scissors.extMarkInfo
local function setupPopupKeymaps(bufnr, winnr, mode, snip, prefixBodySep)
	local maps = require("scissors.config").config.editSnippetPopup.keymaps
	local function keymap(modes, lhs, rhs)
		vim.keymap.set(modes, lhs, rhs, { buffer = bufnr, nowait = true, silent = true })
	end
	local function closePopup()
		if vim.api.nvim_win_is_valid(winnr) then vim.api.nvim_win_close(winnr, true) end
		if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_delete(bufnr, { force = true }) end
	end
	local function confirmChanges()
		local editedLines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local newPrefixCount = getPrefixCount(prefixBodySep)

		-- VALIDATE
		local prefixEmpty = vim.trim(vim.iter(editedLines):take(newPrefixCount):join("\n")) == ""
		if prefixEmpty then
			u.notify("Prefix cannot be empty.", "warn")
			return
		end
		local bodyEmpty = vim.trim(vim.iter(editedLines):skip(newPrefixCount):join("\n")) == ""
		if bodyEmpty then
			u.notify("Body cannot be empty.", "warn")
			return
		end

		convert.updateSnippetInVscodeSnippetFile(snip, editedLines, newPrefixCount)
		closePopup()
	end

	keymap("n", maps.cancel, closePopup)

	-- also close the popup on leaving buffer, ensures there is not leftover
	-- buffer when user closes popup in a different way, such as `:close`.
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = bufnr,
		once = true,
		callback = closePopup,
	})

	keymap("n", maps.saveChanges, confirmChanges)
	-- so people in the habit of saving via `:w` do not get an error
	vim.cmd.cnoreabbrev("<buffer> w ScissorsSave")
	vim.cmd.cnoreabbrev("<buffer> write ScissorsSave")
	vim.api.nvim_buf_create_user_command(bufnr, "ScissorsSave", confirmChanges, {})

	keymap("n", maps.deleteSnippet, function()
		if mode == "new" then
			u.notify("Cannot delete a snippet that has not been saved yet.", "warn")
			return
		end
		rw.deleteSnippet(snip)
		closePopup()
	end)

	keymap("n", maps.duplicateSnippet, function()
		if mode == "new" then
			u.notify("Cannot duplicate a snippet that has not been saved yet.", "warn")
			return
		end
		u.notify(("Duplicating snippet %q"):format(u.snipDisplayName(snip)))
		local currentBody =
			vim.api.nvim_buf_get_lines(bufnr, getPrefixCount(prefixBodySep), -1, false)
		closePopup()
		local snipFile = { path = snip.fullPath, ft = snip.filetype } ---@type Scissors.snipFile
		M.createNewSnipAndEdit(snipFile, currentBody)
	end)

	keymap("n", maps.openInFile, function()
		closePopup()
		-- since there seem to be various escaping issues, simply using `.` to
		-- match any char instead, since a rare wrong location is preferable to
		-- the opening failing
		local locationInFile = snip.originalKey:gsub("[/()%[%] ]", ".")
		vim.cmd(("edit +/%q: %s"):format(locationInFile, snip.fullPath))
	end)

	keymap({ "n", "i" }, maps.insertNextPlaceholder, function()
		local bufText = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
		local numbers = {}
		local placeholderPattern = "${?(%d+)" -- match `$1`, `${2:word}`, or `${3|word|}`
		for placeholder in bufText:gmatch(placeholderPattern) do
			table.insert(numbers, tonumber(placeholder))
		end
		local highestPlaceholder = #numbers > 0 and math.max(unpack(numbers)) or 0

		local insertStr = ("${%s:}"):format(highestPlaceholder + 1)
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { insertStr })

		-- move cursor
		vim.api.nvim_win_set_cursor(0, { row, col + #insertStr - 1 })
		vim.cmd.startinsert()
	end)

	keymap("n", maps.goBackToSearch, function()
		closePopup()
		if mode == "new" then
			require("scissors").addNewSnippet()
		elseif mode == "update" then
			require("scissors").editSnippet()
		end
	end)

	keymap("n", maps.showHelp, function()
		local info = {
			"The popup is just one window, so you can move between the prefix area "
				.. "and the body with `j` and `k` or any other movement command.",
			"",
			"The popup intelligently adapts to changes in the prefix area: Each line represents "
				.. "one prefix, and creating or removing lines in that area thus changes the number of prefixes.",
			"",
			("- [%s] cancel"):format(maps.cancel),
			("- [%s] save changes"):format(maps.saveChanges),
			("- [%s] go back to search"):format(maps.goBackToSearch),
			("- [%s] delete snippet"):format(maps.deleteSnippet),
			("- [%s] duplicate snippet"):format(maps.duplicateSnippet),
			("- [%s] open in file"):format(maps.openInFile),
			("- [%s] insert next placeholder (normal & insert)"):format(maps.insertNextPlaceholder),
			("- [%s] show help"):format(maps.showHelp),
			"",
			"All mappings apply to normal mode (if not noted otherwise).",
		}
		u.notify(table.concat(info, "\n"), "info", { id = "scissors-help", timeout = 10000 })
	end)

	-----------------------------------------------------------------------------

	-- HACK deal with deletion and creation of prefixes on the last line (see #6)
	local function normal(cmd) vim.cmd.normal { cmd, bang = true } end

	keymap("n", "dd", function()
		local prefixCount = getPrefixCount(prefixBodySep)
		local currentLnum = vim.api.nvim_win_get_cursor(0)[1]
		local cmd = currentLnum == prefixCount and "^DkJ" or "dd"
		normal(cmd)
	end)

	keymap("n", "o", function()
		local prefixCount = getPrefixCount(prefixBodySep)
		local currentLnum = vim.api.nvim_win_get_cursor(0)[1]
		local totalLines = vim.api.nvim_buf_line_count(0)
		local cmd = "o"
		if currentLnum == prefixCount and totalLines ~= prefixCount then
			local currentLine = vim.api.nvim_get_current_line()
			vim.api.nvim_buf_set_lines(0, prefixCount - 1, prefixCount - 1, false, { currentLine })
			cmd = "cc"
		end
		normal(cmd)
		vim.cmd.startinsert()
	end)
end

--------------------------------------------------------------------------------

---@param snipFile Scissors.snipFile
---@param bodyPrefill string[]
function M.createNewSnipAndEdit(snipFile, bodyPrefill)
	---@type Scissors.SnippetObj
	local snip = {
		prefix = { "" },
		body = bodyPrefill,
		fullPath = snipFile.path,
		filetype = snipFile.ft,
		fileIsNew = snipFile.fileIsNew,
	}
	M.editInPopup(snip, "new")
end

---@param snip Scissors.SnippetObj
---@param mode "new"|"update"
function M.editInPopup(snip, mode)
	local conf = require("scissors.config").config.editSnippetPopup
	local icon = require("scissors.config").config.icons.scissors
	local ns = vim.api.nvim_create_namespace("nvim-scissors-editing")

	-- snippet properties
	local copy = vim.deepcopy(snip.prefix) -- copy since `list_extend` mutates destination
	local lines = vim.list_extend(copy, snip.body)
	local nameOfSnippetFile = vim.fs.basename(snip.fullPath)

	local bufName, winTitle
	if mode == "update" then
		local displayName = u.snipDisplayName(snip)
		bufName = ("Edit snippet %q"):format(displayName)
		winTitle = ("Editing %q [%s]"):format(displayName, nameOfSnippetFile)
	else
		bufName = "New snippet"
		winTitle = ("New snippet in %q"):format(nameOfSnippetFile)
	end
	winTitle = vim.trim(icon .. " " .. winTitle)

	-- CREATE BUFFER
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_name(bufnr, bufName)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })

	-- prefer only starting treesitter as opposed to setting the buffer filetype,
	-- as this avoid triggering the filetype plugin, which can sometimes entail
	-- undesired effects like LSPs attaching
	local ft = snip.filetype
	if ft == "zsh" or ft == "sh" then ft = "bash" end -- substitute missing `sh` and `zsh` parsers
	pcall(vim.treesitter.start, bufnr, ft) -- errors when no parser available
	vim.bo[bufnr].filetype = require("scissors.config").scissorsFiletype
	local popupZindex = 45 -- below nvim-notify, which uses 50

	-- keymap hints
	local hlgroup = { key = "Keyword", desc = "Comment" }
	local maps = require("scissors.config").config.editSnippetPopup.keymaps
	local footer = {
		{ " normal mode: ", "FloatBorder" },
		{ maps.showHelp, hlgroup.key },
		{ " help", hlgroup.desc },
		{ "  ", "FloatBorder" },
		{ maps.cancel, hlgroup.key },
		{ " cancel", hlgroup.desc },
		{ "  ", "FloatBorder" },
		{ maps.saveChanges, hlgroup.key },
		{ " save", hlgroup.desc },
		{ "  ", "FloatBorder" },
		{ maps.insertNextPlaceholder, hlgroup.key },
		{ " placeholder (normal & insert)", hlgroup.desc },
		{ " ", "FloatBorder" },
	}

	-- CREATE WINDOW
	local winnr = vim.api.nvim_open_win(bufnr, true, {
		-- centered window
		relative = "editor",
		width = math.floor(conf.width * vim.o.columns),
		height = math.floor(conf.height * vim.o.lines),
		row = math.floor((1 - conf.height) * vim.o.lines / 2),
		col = math.floor((1 - conf.width) * vim.o.columns / 2),

		title = " " .. winTitle .. " ",
		title_pos = "center",
		border = conf.border,
		zindex = popupZindex,
		footer = footer,
	})
	vim.wo[winnr].signcolumn = "no"
	vim.wo[winnr].statuscolumn = " " -- just for padding
	vim.wo[winnr].winfixbuf = true
	vim.wo[winnr].conceallevel = 0
	-- reduce scrolloff based on user-set window size
	vim.wo[winnr].sidescrolloff = math.floor(vim.wo.sidescrolloff * conf.width)
	vim.wo[winnr].scrolloff = math.floor(vim.wo.scrolloff * conf.height)
	require("scissors.backdrop").new(bufnr, popupZindex)

	-- move cursor
	if mode == "new" then
		vim.defer_fn(vim.cmd.startinsert, 1)
	elseif mode == "update" then
		local firstLineOfBody = #snip.prefix + 1
		pcall(vim.api.nvim_win_set_cursor, winnr, { firstLineOfBody, 0 })
	end

	-- PREFIX-BODY-SEPARATOR
	-- (INFO its position determines number of prefixes)

	-- style the separator in a way that it does not appear to be two windows, see https://github.com/chrisgrieser/nvim-scissors/issues/24#issuecomment-2561255043
	local separatorChar = "┄"
	local separatorHlgroup = "Comment"

	local winWidth = vim.api.nvim_win_get_width(winnr)
	local prefixBodySep = { bufnr = bufnr, ns = ns, id = -1 } ---@type Scissors.extMarkInfo
	prefixBodySep.id = vim.api.nvim_buf_set_extmark(bufnr, ns, #snip.prefix - 1, 0, {
		virt_lines = {
			{ { (separatorChar):rep(winWidth), separatorHlgroup } },
		},
		virt_lines_leftcol = true,
		-- "above line n" instead of "below line n-1" changes where new lines
		-- occur when creating them. The latter appears to be more intuitive.
		virt_lines_above = false,
	})

	-- PREFIX LABEL
	updatePrefixLabel(#snip.prefix, bufnr) -- initialize
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = bufnr,
		callback = function()
			local newPrefixCount = getPrefixCount(prefixBodySep)
			updatePrefixLabel(newPrefixCount, bufnr)
		end,
	})

	-- MISC
	setupPopupKeymaps(bufnr, winnr, mode, snip, prefixBodySep)
	u.tokenHighlight(bufnr)
end

--------------------------------------------------------------------------------
return M
