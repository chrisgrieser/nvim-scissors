local M = {}

local config = require("scissors.config").config
local rw = require("scissors.read-write-operations")
local u = require("scissors.utils")
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
	local newCount = vim.api.nvim_buf_get_extmark_by_id(extM.bufnr, extM.ns, extM.id, {})[1]
	return newCount
end

--------------------------------------------------------------------------------

---@param pathOfSnippetFile string
---@return string|false filetype
---@nodiscard
local function determineFileType(pathOfSnippetFile)
	-- PRIMARY METHOD: read `package.json` https://code.visualstudio.com/api/language-extensions/snippet-guide
	local relPathOfSnipFile = pathOfSnippetFile:sub(#config.snippetDir + 2)
	local packageJson = rw.readAndParseJson(config.snippetDir .. "/package.json")
	local snipFilesInfo = packageJson.contributes.snippets
	local fileMetadata = vim.tbl_filter(
		function(info) return info.path:gsub("^%.?/", "") == relPathOfSnipFile end,
		snipFilesInfo
	)
	if fileMetadata[1] then
		local lang = fileMetadata[1].language
		if type(lang) == "string" then lang = { lang } end
		lang = vim.tbl_filter(function(l) return l ~= "global" and l ~= "all" end, lang)
		if lang[1] then return lang[1] end
	end

	-- FALLBACK #1: filename is filetype
	local filename = vim.fs.basename(pathOfSnippetFile):gsub("%.json$", "")
	local allKnownFts = vim.fn.getcompletion("", "filetype")
	if vim.tbl_contains(allKnownFts, filename) then return filename end

	-- FALLBACK #2: filename is extension
	local matchedFt = vim.filetype.match { filename = "dummy." .. filename }
	if matchedFt then return matchedFt end

	return false
end

---@param snip SnippetObj snippet to update/create
---@param prefixCount number
---@param editedLines string[]
local function updateSnippetFile(snip, editedLines, prefixCount)
	local snippetsInFile = rw.readAndParseJson(snip.fullPath) ---@cast snippetsInFile VSCodeSnippetDict
	local filepath = snip.fullPath
	local prefix = vim.list_slice(editedLines, 1, prefixCount)
	local body = vim.list_slice(editedLines, prefixCount + 1, #editedLines)

	-- LINT
	-- trim (only trailing for body, since leading there is indentation)
	prefix = vim.tbl_map(function(line) return vim.trim(line) end, prefix)
	body = vim.tbl_map(function(line) return line:gsub("%s+$", "") end, body)
	-- remove deleted prefixes
	prefix = vim.tbl_filter(function(line) return line ~= "" end, prefix)
	-- trim trailing empty lines from body
	while body[#body] == "" do
		vim.notify("🪚 body: " .. vim.inspect(body))
		table.remove(body)
	end
	-- GUARD validate
	if #body == 0 then
		u.notify("Body is empty. No changes made.", "warn")
		return
	end
	if #prefix == 0 then
		u.notify("Prefix is empty. No changes made.", "warn")
		return
	end

	-- new snippet: key = prefix
	local isNewSnippet = snip.originalKey == nil
	local key = table.concat(prefix, " + ")
	-- ensure key is unique
	while isNewSnippet and snippetsInFile[key] ~= nil do
		key = key .. "-1"
	end

	-- convert snipObj to VSCodeSnippet and insert it
	local snipName = u.snipDisplayName(snip)
	snip.originalKey = nil -- delete keys set by this plugin
	snip.fullPath = nil
	snip.body = #body == 1 and body[1] or body -- flatten if only one element
	snip.prefix = #prefix == 1 and prefix[1] or prefix
	---@diagnostic disable-next-line: cast-type-mismatch -- we are converting it here
	---@cast snip VSCodeSnippet
	snippetsInFile[key] = snip

	-- write & notify
	local success = rw.writeAndFormatSnippetFile(filepath, snippetsInFile)
	if success then
		local action = isNewSnippet and "created" or "updated"
		u.notify(("%q %s."):format(snipName, action))
	end
end

--------------------------------------------------------------------------------

---@param snip SnippetObj
---@param mode "new"|"update"
function M.editInPopup(snip, mode)
	local a = vim.api
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

	local ft = determineFileType(snip.fullPath)
	if ft then a.nvim_buf_set_option(bufnr, "filetype", ft) end

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

	-- move cursor
	if mode == "new" then
		vim.cmd.startinsert()
	elseif mode == "update" then
		local firstLineOfBody = #snip.prefix + 1
		pcall(a.nvim_win_set_cursor, winnr, { firstLineOfBody, 0 })
	end

	-- highlight cursor positions
	-- DOCS https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax
	vim.fn.matchadd("DiagnosticVirtualTextInfo", [[\$\d]]) -- tabstops
	vim.fn.matchadd("DiagnosticVirtualTextInfo", [[\${\d:.\{-}}]]) -- placeholders
	vim.fn.matchadd("DiagnosticVirtualTextInfo", [[\${\d|.\{-}|}]]) -- choice

	-- prefixBodySeparator -> INFO its position determines number of prefixes
	local winWidth = a.nvim_win_get_width(winnr)
	local prefixBodySep = { bufnr = bufnr, ns = ns, id = -1 } ---@type extMarkInfo
	prefixBodySep.id = a.nvim_buf_set_extmark(bufnr, ns, #snip.prefix, 0, {
		virt_lines = {
			{ { ("═"):rep(winWidth), "FloatBorder" } },
		},
		virt_lines_leftcol = true,
		-- "above line n" instead of "below line n-1" ensures that creating a new
		-- line at the last line above the virtual line places the line above the
		-- virtual line and not below it.
		virt_lines_above = true,
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
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = bufnr,
		callback = function()
			local newPrefixCount = getPrefixCount(prefixBodySep)
			updatePrefixLabel(newPrefixCount)
		end,
	})

	-- keymaps
	local function close()
		a.nvim_win_close(winnr, true)
		a.nvim_buf_delete(bufnr, { force = true })
	end
	local opts = { buffer = bufnr, nowait = true, silent = true }
	vim.keymap.set("n", conf.keymaps.cancel, close, opts)
	vim.keymap.set("n", conf.keymaps.saveChanges, function()
		local editedLines = a.nvim_buf_get_lines(bufnr, 0, -1, false)
		local newPrefixCount = getPrefixCount(prefixBodySep)
		updateSnippetFile(snip, editedLines, newPrefixCount)
		close()
	end, opts)
	vim.keymap.set("n", conf.keymaps.delete, function()
		if mode == "new" then
			u.notify("Cannot delete a snippet that has not been saved yet.", "warn")
			return
		end
		rw.deleteSnippet(snip)
		close()
	end, opts)
	vim.keymap.set("n", conf.keymaps.openInFile, function()
		close()
		local locationInFile = snip.originalKey:gsub(" ", [[\ ]])
		vim.cmd(("edit +/%q %s"):format(locationInFile, snip.fullPath))
	end, opts)
end

--------------------------------------------------------------------------------
return M
