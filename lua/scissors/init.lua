local M = {}

-- PERF do not require other submodules here, since that loads the entire codebase
-- of the plugin on initialization instead of lazy-loading the parts when needed.
local u = require("scissors.utils")

--------------------------------------------------------------------------------

---@param userConfig? pluginConfig
function M.setup(userConfig) require("scissors.config").setupPlugin(userConfig or {}) end

function M.editSnippet()
	local snippetDir = require("scissors.config").config.snippetDir

	local rw = require("scissors.read-write-operations")
	local vscodeFmt = require("scissors.vscode-format")
	local picker = require("scissors.picker")
	local vb = require("scissors.validate-and-bootstrap")

	-- get all snippets
	if not vb.validate(snippetDir) then return end
	local bufferFt = vim.bo.filetype
	local allSnippets = {} ---@type SnippetObj[]

	for _, absPath in pairs(vscodeFmt.getSnippetFilesForFt(bufferFt)) do
		local vscodeJson = rw.readAndParseJson(absPath) ---@cast vscodeJson VSCodeSnippetDict
		local snipsInFile = vscodeFmt.restructureVsCodeObj(vscodeJson, absPath, bufferFt)
		vim.list_extend(allSnippets, snipsInFile)
	end
	for _, absPath in pairs(vscodeFmt.getSnippetFilesForFt("all")) do
		local vscodeJson = rw.readAndParseJson(absPath) ---@cast vscodeJson VSCodeSnippetDict
		local snipsInFile = vscodeFmt.restructureVsCodeObj(vscodeJson, absPath, "plaintext")
		vim.list_extend(allSnippets, snipsInFile)
	end
	if #allSnippets == 0 then
		u.notify("No snippets found for filetype: " .. bufferFt, "warn")
		return
	end

	-- select
	picker.selectSnippet(allSnippets)
end

function M.addNewSnippet()
	local snippetDir = require("scissors.config").config.snippetDir

	local vb = require("scissors.validate-and-bootstrap")
	local vscodeFmt = require("scissors.vscode-format")

	-- validate & bootstrap
	if not vb.validate(snippetDir) then return end
	vb.bootstrapSnipDir(snippetDir)

	-- if visual mode, prefill body with selected text
	local bodyPrefill = { "" }
	local mode = vim.fn.mode()
	if mode:find("[Vv]") then
		u.leaveVisualMode() -- necessary so `<` and `>` marks are set
		local startRow, startCol = unpack(vim.api.nvim_buf_get_mark(0, "<"))
		local endRow, endCol = unpack(vim.api.nvim_buf_get_mark(0, ">"))
		endCol = mode:find("V") and -1 or (endCol + 1)
		bodyPrefill = vim.api.nvim_buf_get_text(0, startRow - 1, startCol, endRow - 1, endCol, {})
		bodyPrefill = u.dedent(bodyPrefill)
	end

	-- get list of all snippet files which matching filetype
	local ft = vim.bo.filetype
	local snipFilesForFt = vim.tbl_map(
		function(file) return { path = file, ft = ft } end,
		vscodeFmt.getSnippetFilesForFt(ft)
	)
	local snipFilesForAll = vim.tbl_map(
		function(file) return { path = file, ft = "plaintext" } end,
		vscodeFmt.getSnippetFilesForFt("all")
	)

	---@alias snipFile {path: string, ft: string}
	---@type snipFile[]
	local allSnipFiles = vim.list_extend(snipFilesForFt, snipFilesForAll)

	-- create new snippet file, if non exists for the directory
	if #allSnipFiles == 0 then
		local newSnipFile = vb.bootstrapSnippetFile(ft)
		table.insert(allSnipFiles, newSnipFile)
	end

	if #allSnipFiles == 1 then
		-- if only one snippet file for the filetype, skip the picker and add directory
		require("scissors.edit-popup").createNewSnipAndEdit(allSnipFiles[1], bodyPrefill)
	else
		require("scissors.picker").addSnippet(allSnipFiles, bodyPrefill)
	end
end

--------------------------------------------------------------------------------
return M
