-- functions for converting from/to the VSCode Snippet Format
--------------------------------------------------------------------------------
local M = {}

local rw = require("scissors.vscode-format.read-write")
local u = require("scissors.utils")
local config = require("scissors.config").config

--------------------------------------------------------------------------------

---@param filetype "all"|string
---@return string[] absPathsOfSnipFileForThisFt
function M.getSnippetFilesForFt(filetype)
	local packageJson = rw.readAndParseJson(config.snippetDir .. "/package.json")
	---@cast packageJson packageJson

	local snipFilesInfos = packageJson.contributes.snippets

	local absPaths = {}
	for _, info in pairs(snipFilesInfos) do
		local lang = info.language
		if type(lang) == "string" then lang = { lang } end
		if vim.tbl_contains(lang, filetype) then
			local absPath = config.snippetDir .. "/" .. info.path:gsub("^%.?/", "")
			table.insert(absPaths, absPath)
		end
	end
	return absPaths
end

--------------------------------------------------------------------------------

---1. convert dictionary to array for `vim.ui.select`
---2. make body & prefix consistent array for nvim-api functions
---3. inject filepath into the snippet for convenience later on
---@param vscodeJson VSCodeSnippetDict
---@param filetype string filetype to assign to all snippets in the file
---@return SnippetObj[]
function M.restructureVsCodeObj(vscodeJson, filepath, filetype)
	local snippetsInFileList = {} ---@type SnippetObj[]

	-- convert dictionary to array
	for key, snip in pairs(vscodeJson) do
		---@diagnostic disable-next-line: cast-type-mismatch we are converting it here
		---@cast snip SnippetObj
		snip.fullPath = filepath
		snip.originalKey = key
		snip.filetype = filetype
		table.insert(snippetsInFileList, snip)
	end

	for _, snip in ipairs(snippetsInFileList) do
		-- VS Code allows body and prefix to be a string. Converts to array on
		-- read for easier handling
		local rawPrefix = type(snip.prefix) == "string" and { snip.prefix } or snip.prefix
		local rawBody = type(snip.body) == "string" and { snip.body } or snip.body
		---@cast rawPrefix string[] -- ensured above
		---@cast rawBody string[] -- ensured above

		-- Strings can contain lines breaks, but nvim-api function expect each
		-- string representing single line, so we are converting them.
		local cleanBody, cleanPrefix = {}, {}
		for _, str in ipairs(rawBody) do
			local lines = vim.split(str, "\n")
			vim.list_extend(cleanBody, lines)
		end
		for _, str in ipairs(rawPrefix) do
			local lines = vim.split(str, "\n")
			vim.list_extend(cleanPrefix, lines)
		end

		snip.prefix, snip.body = cleanPrefix, cleanBody
	end
	return snippetsInFileList
end

---@param snip SnippetObj snippet to update/create
---@param prefixCount number
---@param editedLines string[]
function M.updateSnippetFile(snip, editedLines, prefixCount)
	local snippetsInFile = rw.readAndParseJson(snip.fullPath) ---@cast snippetsInFile VSCodeSnippetDict
	local filepath = snip.fullPath
	local prefix = vim.list_slice(editedLines, 1, prefixCount)
	local body = vim.list_slice(editedLines, prefixCount + 1, #editedLines)
	local snippetWasUpdated = snip.originalKey ~= nil

	-- LINT
	prefix = vim
		.iter(prefix)
		:map(function(line) return vim.trim(line) end)
		:filter(function(line) return line ~= "" end) -- remove deleted prefixes
		:totable()
	-- trim trailing empty lines from body
	while body[#body] == "" do
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

	-- convert snipObj to VSCodeSnippet
	---@type VSCodeSnippet
	local vsCodeSnip = {
		body = #body == 1 and body[1] or body, -- flatten if only one element
		prefix = #prefix == 1 and prefix[1] or prefix,
	}

	-- insert item at a new key
	if snippetWasUpdated then snippetsInFile[snip.originalKey] = nil end -- remove from old key
	local key = table.concat(prefix, " + ")
	while snippetsInFile[key] ~= nil do -- ensure new key is unique
		key = key .. "-1"
	end
	snippetsInFile[key] = vsCodeSnip -- insert at new key

	-- write & notify
	local success = rw.writeAndFormatSnippetFile(filepath, snippetsInFile, snip.fileIsNew)
	if success then
		local snipName = u.snipDisplayName(vsCodeSnip)
		local action = snippetWasUpdated and "updated" or "created"
		u.notify(("%q %s."):format(snipName, action))
	end
end

--------------------------------------------------------------------------------
return M
