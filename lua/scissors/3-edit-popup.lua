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

---using only utf symbols, so they work for users without nerd fonts
---@param hint string
---@return string
local function shortenKeymapHintsWithSymbols(hint)
	local shortened = hint
		:gsub("<[Cc][Rr]>", "↩")
		:gsub("<[dD]own>", "↓")
		:gsub("<[Uu]p>", "↑")
		:gsub("<[Rr]ight>", "→")
		:gsub("<[Ll]eft>", "←")
		:gsub("<[Tt]ab>", "⭾ ")
		:gsub("<[Ss]pace>", "⎵")
		:gsub("<[Bb][Ss]>", "⌫")
	return shortened
end

---@param mode "new"|"update"
---@param maxLength number
---@return string
local function generateKeymapHints(mode, maxLength)
	local mappings = require("scissors.config").config.editSnippetPopup.keymaps
	local keymapHints = ("%s: Save  %s: Cancel"):format(mappings.saveChanges, mappings.cancel)
	local extraHints = {
		mappings.goBackToSearch .. ": Back",
		mappings.deleteSnippet .. ": Delete",
		mappings.insertNextPlaceholder .. ": Placeholder",
		mappings.openInFile .. ": Open File",
	}
	if mode ~= "new" then table.insert(extraHints, mappings.duplicateSnippet .. ": Duplicate") end

	keymapHints = shortenKeymapHintsWithSymbols(keymapHints)
	extraHints = vim.tbl_map(shortenKeymapHintsWithSymbols, extraHints)
	local borderAndPadding = 2 + 2 + 2
	repeat
		-- shuffle hints, so user sees different ones when there is not enough space
		local nextHint = table.remove(extraHints, math.random(#extraHints))
		local hintLen = vim.api.nvim_strwidth(keymapHints) + #nextHint + borderAndPadding
		if hintLen > maxLength then break end
		keymapHints = keymapHints .. "  " .. nextHint
	until #extraHints == 0
	return keymapHints
end

---@param bufnr number
---@param winnr number
---@param mode "new"|"update"
---@param snip Scissors.SnippetObj
---@param prefixBodySep Scissors.extMarkInfo
local function setupPopupKeymaps(bufnr, winnr, mode, snip, prefixBodySep)
	local mappings = require("scissors.config").config.editSnippetPopup.keymaps
	local keymap = vim.keymap.set
	local opts = { buffer = bufnr, nowait = true, silent = true }
	local function closePopup()
		if vim.api.nvim_win_is_valid(winnr) then vim.api.nvim_win_close(winnr, true) end
		if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_delete(bufnr, { force = true }) end
	end
	local function confirmChanges()
		local editedLines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local newPrefixCount = getPrefixCount(prefixBodySep)
		convert.updateSnippetInVscodeSnippetFile(snip, editedLines, newPrefixCount)
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
		local currentBody =
			vim.api.nvim_buf_get_lines(bufnr, getPrefixCount(prefixBodySep), -1, false)
		closePopup()
		local snipFile = { path = snip.fullPath, ft = snip.filetype } ---@type Scissors.snipFile
		M.createNewSnipAndEdit(snipFile, currentBody)
	end, opts)

	keymap("n", mappings.openInFile, function()
		closePopup()
		-- since there seem to be various escaping issues, simply using `.` to
		-- match any char instead, since a rare wrong location is preferable to
		-- the opening failing
		local locationInFile = snip.originalKey:gsub("[/()%[%] ]", ".")
		vim.cmd(("edit +/%q: %s"):format(locationInFile, snip.fullPath))
	end, opts)

	keymap({ "n", "i" }, mappings.insertNextPlaceholder, function()
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
	end, opts)

	keymap("n", mappings.goBackToSearch, function()
		closePopup()
		if mode == "new" then
			require("scissors").addNewSnippet()
		elseif mode == "update" then
			require("scissors").editSnippet()
		end
	end, opts)

	-----------------------------------------------------------------------------

	-- HACK deal with deletion and creation of prefixes on the last line (see #6)
	local function normal(cmd) vim.cmd.normal { cmd, bang = true } end

	keymap("n", "dd", function()
		local prefixCount = getPrefixCount(prefixBodySep)
		local currentLnum = vim.api.nvim_win_get_cursor(0)[1]
		local cmd = currentLnum == prefixCount and "^DkJ" or "dd"
		normal(cmd)
	end, opts)

	keymap("n", "o", function()
		local prefixCount = getPrefixCount(prefixBodySep)
		local currentLnum = vim.api.nvim_win_get_cursor(0)[1]
		local cmd = "o"
		if currentLnum == prefixCount then
			local currentLine = vim.api.nvim_get_current_line()
			vim.api.nvim_buf_set_lines(0, prefixCount - 1, prefixCount - 1, false, { currentLine })
			cmd = "cc"
		end
		normal(cmd)
		vim.cmd.startinsert()
	end, opts)
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
	local keymapHints = generateKeymapHints(mode, math.floor(conf.width * vim.o.columns - 2))

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
		footer = { { " " .. keymapHints .. " ", "FloatBorder" } },
	})
	vim.wo[winnr].signcolumn = "no"
	vim.wo[winnr].winfixbuf = true
	vim.wo[winnr].conceallevel = 0
	-- reduce scrolloff based on user-set window size
	vim.wo[winnr].sidescrolloff = math.floor(vim.wo.sidescrolloff * conf.width)
	vim.wo[winnr].scrolloff = math.floor(vim.wo.scrolloff * conf.height)
	require("scissors.backdrop").new(bufnr, popupZindex)

	-- move cursor
	if mode == "new" then
		vim.defer_fn(vim.cmd.startinsert, 1) -- for whatever reason needs to be deferred to work reliably
	elseif mode == "update" then
		local firstLineOfBody = #snip.prefix + 1
		pcall(vim.api.nvim_win_set_cursor, winnr, { firstLineOfBody, 0 })
	end

	-- PREFIX-BODY-SEPARATOR
	-- (INFO its position determines number of prefixes)

	-- style the separator in a way that it does not appear to be two windows
	-- (see https://github.com/chrisgrieser/nvim-scissors/issues/24#issuecomment-2561255043)
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

	-- continuously update highlight prefix lines and add label
	local labelExtMarkIds = {} ---@type number[]
	local function updatePrefixLabel(newPrefixCount) ---@param newPrefixCount number
		for _, label in pairs(labelExtMarkIds) do
			vim.api.nvim_buf_del_extmark(bufnr, ns, label)
		end
		for i = 1, newPrefixCount do
			local ln = i - 1
			local label = newPrefixCount == 1 and "Prefix" or "Prefix #" .. i
			vim.api.nvim_buf_add_highlight(bufnr, ns, "DiagnosticVirtualTextHint", ln, 0, -1)
			local id = vim.api.nvim_buf_set_extmark(bufnr, ns, ln, 0, {
				virt_text = { { label, "Todo" } },
				virt_text_pos = "right_align",
			})
			table.insert(labelExtMarkIds, id)
		end
	end
	updatePrefixLabel(#snip.prefix) -- initialize

	-- update in case prefix count changes due to user input
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = bufnr,
		callback = function()
			local newPrefixCount = getPrefixCount(prefixBodySep)
			updatePrefixLabel(newPrefixCount)
		end,
	})

	-- MISC
	setupPopupKeymaps(bufnr, winnr, mode, snip, prefixBodySep)
	u.tokenHighlight(bufnr)
end

--------------------------------------------------------------------------------
return M
