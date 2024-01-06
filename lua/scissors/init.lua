local M = {}

-- PERF do not require other submodules here, since that loads the entire codebase
-- of the plugin on initialization instead of lazy-loading the parts when needed.
local u = require("scissors.utils")

--------------------------------------------------------------------------------

---@return string|nil snippetDir nil when the directory does not exist
---@nodiscard
local function getSnippetDir()
	local snippetDir = require("scissors.config").config.snippetDir
	local stat = vim.loop.fs_stat(snippetDir)
	local exists = stat and stat.type == "directory"
	if exists then return snippetDir end

	u.notify("Snippet directory does not exist: " .. snippetDir, "error")
	return nil
end

--------------------------------------------------------------------------------

---@param userConfig? pluginConfig
function M.setup(userConfig) require("scissors.config").setupPlugin(userConfig or {}) end

function M.editSnippet()
	local snippetDir = getSnippetDir()
	if not snippetDir then return end

	local rw = require("scissors.read-write-operations")
	local vscodeFmt = require("scissors.vscode-format")
	local picker = require("scissors.picker")

	-- get all snippets
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

	-- SELECT
	picker.selectSnippet(allSnippets)
end

function M.addNewSnippet()
	local snippetDir = getSnippetDir()
	if not snippetDir then return end

	local vscodeFmt = require("scissors.vscode-format")
	local picker = require("scissors.picker")

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
	local snipFilesForFt = vim.tbl_map(
		function(file) return { path = file, ft = vim.bo.filetype } end,
		vscodeFmt.getSnippetFilesForFt(vim.bo.filetype)
	)
	local snipFilesForAll = vim.tbl_map(
		function(file) return { path = file, ft = "plaintext" } end,
		vscodeFmt.getSnippetFilesForFt("all")
	)

	---@alias snipFile {path: string, ft: string}
	---@type snipFile[]
	local allSnipFiles = vim.list_extend(snipFilesForFt, snipFilesForAll) 

	-- SELECT
	picker.addSnippet(allSnipFiles, bodyPrefill)
end

--------------------------------------------------------------------------------
return M
