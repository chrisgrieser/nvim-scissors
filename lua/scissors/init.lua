local M = {}

-- PERF do not require other submodules here, since that loads the entire codebase
-- of the plugin on initialization instead of lazy-loading the parts when needed.
local u = require("scissors.utils")

---@param snipDir string
---@return boolean
---@nodiscard
local function validateAndBootstrapSnipDir(snipDir)
	local rw = require("scissors.read-write-operations")
	local snipDirInfo = vim.loop.fs_stat(snipDir)
	local packageJsonExists = vim.loop.fs_stat(snipDir .. "/package.json") ~= nil

	-- validate
	if snipDirInfo and snipDirInfo.type ~= "directory" then
		u.notify(("%q is not a directory."):format(snipDir), "error")
		return false
	elseif snipDirInfo and packageJsonExists then
		local packageJson = rw.readAndParseJson(snipDir .. "/package.json")
		if
			vim.tbl_isempty(packageJson)
			or not (packageJson.contributes and packageJson.contributes.snippets)
		then
			u.notify(
				"The `package.json` in your snippetDir is invalid.\n"
					.. "Please make sure it follows the required specification for VSCode snippets.",
				"error"
			)
			return false
		end
	elseif snipDir:find("/friendly%-snippets/") then
		u.notify(
			"Snippets from friendly-snippets should be edited directly, since any changes would be overwritten as soon as the repo is updated.\n" ..
			"Copy the snippet files you want from the repo into your snippet directory and edit them there.",
			"error"
		)
		return false
	end

	-- bootstrap if snippetDir or `package.json` does not exist
	if not snipDirInfo then vim.fn.mkdir(snipDir, "p") end
	return true
end

--------------------------------------------------------------------------------

---@param userConfig? pluginConfig
function M.setup(userConfig) require("scissors.config").setupPlugin(userConfig or {}) end

function M.editSnippet()
	local snippetDir = require("scissors.config").config.snippetDir
	if not validateAndBootstrapSnipDir(snippetDir) then return end

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
	if #allSnippets == 0 then
		u.notify("No snippets found for filetype: " .. bufferFt, "warn")
		return
	end

	-- select
	picker.selectSnippet(allSnippets)
end

function M.addNewSnippet()
	local snippetDir = require("scissors.config").config.snippetDir
	if not validateAndBootstrapSnipDir(snippetDir) then return end

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
	local vscodeFmt = require("scissors.vscode-format")
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

	if #allSnipFiles == 0 then
		u.notify("No snippet files found for filetype: " .. ft, "warn")
	elseif #allSnipFiles == 1 then
		-- if only one snippet file for the filetype, skip the picker and add directory
		require("scissors.edit-popup").createNewSnipAndEdit(allSnipFiles[1], bodyPrefill)
	else
		require("scissors.picker").addSnippet(allSnipFiles, bodyPrefill)
	end
end

--------------------------------------------------------------------------------
return M
