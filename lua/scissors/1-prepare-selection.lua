local M = {}

local convert = require("scissors.vscode-format.convert-object")
local u = require("scissors.utils")
local vb = require("scissors.vscode-format.validate-bootstrap")
--------------------------------------------------------------------------------

---@param lines string[]
---@return string[] dedentedLines
---@nodiscard
local function dedentAndTrimBlanks(lines)
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

--------------------------------------------------------------------------------

function M.editSnippet()
	local snippetDir = require("scissors.config").config.snippetDir

	-- GUARD
	if not vb.validate(snippetDir) then return end
	local packageJsonExist = u.fileExists(snippetDir .. "/package.json")
	if not packageJsonExist then
		u.notify(
			"Your snippet directory is missing a `package.json`.\n"
				.. "The file can be bootstrapped by adding a new snippet via:\n"
				.. ":ScissorsAddNewSnippet",
			"warn"
		)
		return
	end

	-- GET ALL SNIPPETS
	local bufferFt = vim.bo.filetype
	local allSnippets = {} ---@type Scissors.SnippetObj[]
	for _, absPath in pairs(convert.getSnippetfilePathsForFt(bufferFt)) do
		local filetypeSnippets = convert.readVscodeSnippetFile(absPath, bufferFt)
		vim.list_extend(allSnippets, filetypeSnippets)
	end
	for _, absPath in pairs(convert.getSnippetfilePathsForFt("all")) do
		local globalSnippets = convert.readVscodeSnippetFile(absPath, "all")
		vim.list_extend(allSnippets, globalSnippets)
	end

	-- GUARD
	if #allSnippets == 0 then
		u.notify("No snippets found for filetype: " .. bufferFt, "warn")
		return
	end

	-- SELECT
	require("scissors.2-picker.picker-choice").selectSnippet(allSnippets)
end

function M.addNewSnippet(exCmdArgs)
	local snippetDir = require("scissors.config").config.snippetDir

	-- GUARD & bootstrap
	if not vb.validate(snippetDir) then return end
	vb.bootstrapSnipDirIfNeeded(snippetDir)

	-- PARAMS
	local bufferFt = vim.bo.filetype
	exCmdArgs = exCmdArgs or {}

	-- VISUAL MODE: prefill body with selected text
	local bodyPrefill = { "" }
	local mode = vim.fn.mode()
	local calledFromVisualMode = mode:find("[vV]")
	local calledFromExCmd = exCmdArgs.range and exCmdArgs.range > 0
	if calledFromVisualMode then
		vim.cmd.normal { mode, bang = true } -- leave visual mode so `<`/`>` marks are set
		local startRow, startCol = unpack(vim.api.nvim_buf_get_mark(0, "<"))
		local endRow, endCol = unpack(vim.api.nvim_buf_get_mark(0, ">"))
		endCol = mode:find("V") and -1 or (endCol + 1)
		bodyPrefill = vim.api.nvim_buf_get_text(0, startRow - 1, startCol, endRow - 1, endCol, {})
	elseif calledFromExCmd then
		bodyPrefill =
			vim.api.nvim_buf_get_text(0, exCmdArgs.line1 - 1, 0, exCmdArgs.line2 - 1, -1, {})
	end
	if calledFromExCmd or calledFromVisualMode then
		bodyPrefill = dedentAndTrimBlanks(bodyPrefill)
		-- escape `$`
		bodyPrefill = vim.tbl_map(function(line) return line:gsub("%$", "\\$") end, bodyPrefill)
	end

	-- GET LIST OF ALL SNIPPET FILES WITH MATCHING FILETYPE
	local snipFilesForFt = vim.tbl_map(
		function(file) return { path = file, ft = bufferFt } end,
		convert.getSnippetfilePathsForFt(bufferFt)
	)
	local snipFilesForAll = vim.tbl_map(
		function(file) return { path = file, ft = "plaintext" } end,
		convert.getSnippetfilePathsForFt("all")
	)
	---@type Scissors.snipFile[]
	local allSnipFiles = vim.list_extend(snipFilesForFt, snipFilesForAll)

	-- GUARD file listed in `package.json` does not exist
	for _, snipFile in ipairs(allSnipFiles) do
		if not u.fileExists(snipFile.path) then
			local relPath = snipFile.path:sub(#snippetDir + 1)
			local msg = ("%q is listed as a file in the `package.json` "):format(relPath)
				.. "but it does not exist. Aborting."
			u.notify(msg, "error")
			return
		end
	end

	-- BOOTSTRAP new snippet file, if none exists
	if #allSnipFiles == 0 then
		u.notify(("No snippet file found for filetype: %s.\nBootstrapping one."):format(bufferFt))
		local newSnipFile = vb.bootstrapSnippetFile(bufferFt)
		table.insert(allSnipFiles, newSnipFile)
	end

	-- SELECT
	if #allSnipFiles == 1 then
		require("scissors.3-edit-popup").createNewSnipAndEdit(allSnipFiles[1], bodyPrefill)
	else
		require("scissors.2-picker.vim-ui-select").addSnippet(allSnipFiles, bodyPrefill)
	end
end

--------------------------------------------------------------------------------
return M
