local M = {}

local config = require("scissors.config").config
local rw = require("scissors.read-write-operations")
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@param pathOfSnippetFile string
---@return string|false filetype
---@nodiscard
local function guessFileType(pathOfSnippetFile)
	-- primary: read `package.json` https://code.visualstudio.com/api/language-extensions/snippet-guide
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

	-- fallback #1: filename is filetype
	local filename = vim.fs.basename(pathOfSnippetFile):gsub("%.json$", "")
	local allKnownFts = vim.fn.getcompletion("", "filetype")
	if vim.tbl_contains(allKnownFts, filename) then return filename end

	-- fallback #2: filename is extension
	local matchedFt = vim.filetype.match { filename = "dummy." .. filename }
	if matchedFt then return matchedFt end

	return false
end

--------------------------------------------------------------------------------

---@param snip snippetObj
---@param mode "new"|"update"
function M.editInPopup(snip, mode)
	local a = vim.api
	local conf = config.editSnippetPopup

	-- snippet properties
	local body = type(snip.body) == "string" and { snip.body } or snip.body ---@cast body string[]
	local prefix = type(snip.prefix) == "string" and { snip.prefix } or snip.prefix ---@cast prefix string[]
	local numOfPrefixes = #prefix -- needs to be saved as list_extend mutates `prefix`
	local snipLines = vim.list_extend(prefix, body)
	local nameOfSnippetFile = vim.fs.basename(snip.fullPath)

	-- title
	local displayName = mode == "new" and "New Snippet" or snip.originalKey:sub(1, 25)
	local title = mode == "new" and (" New Snippet in %q "):format(nameOfSnippetFile)
		or (" Editing %q [%s] "):format(displayName, nameOfSnippetFile)

	-- create buffer and window
	local bufnr = a.nvim_create_buf(false, true)
	a.nvim_buf_set_lines(bufnr, 0, -1, false, snipLines)
	a.nvim_buf_set_name(bufnr, displayName)
	local guessedFt = guessFileType(snip.fullPath)
	if guessedFt then a.nvim_buf_set_option(bufnr, "filetype", guessedFt) end
	a.nvim_buf_set_option(bufnr, "buftype", "nofile")

	local winnr = a.nvim_open_win(bufnr, true, {
		relative = "win",
		title = title,
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
		local firstLineOfBody = numOfPrefixes + 1
		a.nvim_win_set_cursor(winnr, { firstLineOfBody, 0 })
	end

	-- highlight cursor positions like `$0` or `${1:foo}`
	vim.fn.matchadd("DiagnosticVirtualTextInfo", [[\$\d]])
	vim.fn.matchadd("DiagnosticVirtualTextInfo", [[\${\d:.\{-}}]])

	-- highlight prefix lines and add label
	local ns = a.nvim_create_namespace("nvim-scissors")
	for i = 1, numOfPrefixes do
		local ln = i - 1
		local label = numOfPrefixes == 1 and "Prefix" or "Prefix #" .. i
		a.nvim_buf_add_highlight(bufnr, ns, "DiagnosticVirtualTextHint", ln, 0, -1)
		a.nvim_buf_set_extmark(bufnr, ns, ln, 0, {
			virt_text = { { label, "Todo" } },
			virt_text_pos = "right_align",
		})
	end
	-- win separator as virtual line
	local winWidth = a.nvim_win_get_width(winnr)
	a.nvim_buf_set_extmark(bufnr, ns, numOfPrefixes - 1, 0, {
		virt_lines = {
			{ { ("═"):rep(winWidth), "FloatBorder" } },
		},
		virt_lines_leftcol = true,
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
		rw.updateSnippetFile(snip, editedLines)
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

	-- HACK prevent shifting of extmarks and highlights by disabling keys that
	-- create new lines. (Cannot find a way to make extmarks fixed.)
	local disabledKeys = {
		["O"] = "n",
		["o"] = "n",
		["<CR>"] = "i",
		["dd"] = "n",
	}
	for key, vimMode in pairs(disabledKeys) do
		vim.keymap.set(vimMode, key, function()
			local row = a.nvim_win_get_cursor(0)[1]
			if row <= numOfPrefixes then return end
			return key
		end, { buffer = bufnr, expr = true })
	end
end

--------------------------------------------------------------------------------
return M
