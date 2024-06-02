local version = vim.version()
if version.major == 0 and version.minor < 10 then
	vim.notify("nvim-scissors requires at least nvim 0.10.", vim.log.levels.WARN)
	return
end
--------------------------------------------------------------------------------

local M = {}

-- PERF do not require other submodules here, since that loads the entire codebase
-- of the plugin on initialization instead of lazy-loading the code only when needed.
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@param userConfig? pluginConfig
function M.setup(userConfig) require("scissors.config").setupPlugin(userConfig or {}) end

function M.editSnippet()
	local snippetDir = require("scissors.config").config.snippetDir

	local rw = require("scissors.vscode-format.read-write")
	local convert = require("scissors.vscode-format.convert-object")
	local picker = require("scissors.picker.picker-choice")
	local vb = require("scissors.vscode-format.validate-bootstrap")

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

	-- get all snippets
	local bufferFt = vim.bo.filetype
	local allSnippets = {} ---@type SnippetObj[]

	for _, absPath in pairs(convert.getSnippetFilesForFt(bufferFt)) do
		local vscodeJson = rw.readAndParseJson(absPath) ---@cast vscodeJson VSCodeSnippetDict
		local snipsInFile = convert.restructureVsCodeObj(vscodeJson, absPath, bufferFt)
		vim.list_extend(allSnippets, snipsInFile)
	end
	for _, absPath in pairs(convert.getSnippetFilesForFt("all")) do
		local vscodeJson = rw.readAndParseJson(absPath) ---@cast vscodeJson VSCodeSnippetDict
		local snipsInFile = convert.restructureVsCodeObj(vscodeJson, absPath, "plaintext")
		vim.list_extend(allSnippets, snipsInFile)
	end

	-- GUARD
	if #allSnippets == 0 then
		u.notify("No snippets found for filetype: " .. bufferFt, "warn")
		return
	end

	-- select
	picker.selectSnippet(allSnippets)
end

function M.addNewSnippet(args)
	args = args or {}
	local snippetDir = require("scissors.config").config.snippetDir

	local vb = require("scissors.vscode-format.validate-bootstrap")
	local convert = require("scissors.vscode-format.convert-object")
	local bufferFt = vim.bo.filetype

	-- GUARD & bootstrap
	if not vb.validate(snippetDir) then return end
	vb.bootstrapSnipDir(snippetDir)

	-- if visual mode, prefill body with selected text
	local bodyPrefill = { "" }
	local mode = vim.fn.mode()

	-- visual mode: prefill with selection
	if mode:find("[Vv]") then
		u.leaveVisualMode() -- necessary so `<` and `>` marks are set
		local startRow, startCol = unpack(vim.api.nvim_buf_get_mark(0, "<"))
		local endRow, endCol = unpack(vim.api.nvim_buf_get_mark(0, ">"))
		endCol = mode:find("V") and -1 or (endCol + 1)
		bodyPrefill = vim.api.nvim_buf_get_text(0, startRow - 1, startCol, endRow - 1, endCol, {})
		bodyPrefill = u.dedent(bodyPrefill)

	-- called with arguments (`:ScissorsAddNewSnippet`)
	elseif type(args.range) == "number" and args.range > 0 then
		local endRow = args.range == 2 and args.line2 or args.line1
		bodyPrefill = vim.api.nvim_buf_get_text(0, args.line1 - 1, 0, endRow - 1, -1, {})
		bodyPrefill = u.dedent(bodyPrefill)
	end

	-- get list of all snippet files with matching filetype
	local snipFilesForFt = vim.tbl_map(
		function(file) return { path = file, ft = bufferFt } end,
		convert.getSnippetFilesForFt(bufferFt)
	)
	local snipFilesForAll = vim.tbl_map(
		function(file) return { path = file, ft = "plaintext" } end,
		convert.getSnippetFilesForFt("all")
	)

	---@type snipFile[]
	local allSnipFiles = vim.list_extend(snipFilesForFt, snipFilesForAll)

	-- Create files that are specified in `package.json` but do not exist
	for _, snipFile in ipairs(allSnipFiles) do
		if not u.fileExists(snipFile.path) then
			local readwrite = require("scissors.vscode-format.read-write")
			readwrite.writeFile(snipFile.path, "{}")
		end
	end

	-- bootstrap new snippet file, if none exists
	if #allSnipFiles == 0 then
		local newSnipFile = vb.bootstrapSnippetFile(bufferFt)
		if not newSnipFile then return end
		table.insert(allSnipFiles, newSnipFile)
	end

	-- if only one snippet file for the filetype, skip picker and add directly
	if #allSnipFiles == 1 then
		require("scissors.edit-popup").createNewSnipAndEdit(allSnipFiles[1], bodyPrefill)
	else
		require("scissors.picker.picker-choice").addSnippet(allSnipFiles, bodyPrefill)
	end
end

--------------------------------------------------------------------------------
return M
