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

	-- let user select
	vim.ui.select(allSnippets, {
		prompt = "Select snippet:",
		format_item = function(snip)
			local snipName = u.snipDisplayName(snip)
			local filename = vim.fs.basename(snip.fullPath):gsub("%.json$", "")
			return ("%s\t\t[%s]"):format(snipName, filename)
		end,
		kind = "nvim-scissors.snippetSearch",
	}, function(snip)
		if not snip then return end
		require("scissors.edit-popup").editInPopup(snip, "update")
	end)
end

function M.addNewSnippet()
	local snippetDir = getSnippetDir()
	if not snippetDir then return end

	local vscodeFmt = require("scissors.vscode-format")

	-- visual mode: prefill body with selected text
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
	local allSnipFiles = vim.list_extend(snipFilesForFt, snipFilesForAll)

	-- let user select from
	vim.ui.select(allSnipFiles, {
		prompt = "Select file for new snippet:",
		format_item = function(item)
			local relPath = item.path:sub(#snippetDir + 2)
			return relPath:gsub("%.jsonc?$", "")
		end,
		kind = "nvim-scissors.fileSelect",
	}, function(snipFile)
		if not snipFile then return end

		---@type SnippetObj
		local snip = {
			prefix = { "" },
			body = bodyPrefill,
			fullPath = snipFile.path,
			filetype = snipFile.ft,
		}
		require("scissors.edit-popup").editInPopup(snip, "new")
	end)
end

--------------------------------------------------------------------------------
return M
