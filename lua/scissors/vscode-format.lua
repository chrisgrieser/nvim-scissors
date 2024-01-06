-- functions for converting from/to the VSCode Snippet Format
--------------------------------------------------------------------------------
local M = {}

local rw = require("scissors.read-write-operations")
local u = require("scissors.utils")
local config = require("scissors.config").config

--------------------------------------------------------------------------------

---DOCS https://code.visualstudio.com/api/language-extensions/snippet-guide
---@alias packageJson { contributes: { snippets: snippetFileMetadata[] } }

---@class (exact) snippetFileMetadata
---@field language string|string[]
---@field path string

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

---@class SnippetObj used by this plugin
---@field fullPath string (key only set by this plugin)
---@field filetype string (key only set by this plugin)
---@field originalKey? string if not set, is a new snippet (key only set by this plugin)
---@field prefix string[] -- VS Code allows single string, but this plugin converts to array on read
---@field body string[] -- VS Code allows single string, but this plugin converts to array on read
---@field description? string

---DOCS https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets
---@alias VSCodeSnippetDict table<string, VSCodeSnippet>

---@class VSCodeSnippet
---@field prefix string|string[]
---@field body string|string[]
---@field description? string

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
	local isNewSnippet = snip.originalKey == nil

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

	-- convert snipObj to VSCodeSnippet
	local originalKey = snip.originalKey
	snip.originalKey = nil -- delete keys set by this plugin
	snip.fullPath = nil
	snip.body = #body == 1 and body[1] or body -- flatten if only one element
	snip.prefix = #prefix == 1 and prefix[1] or prefix
	---@diagnostic disable-next-line: cast-type-mismatch -- we are converting it here
	---@cast snip VSCodeSnippet

	-- move item to new key
	if originalKey ~= nil then snippetsInFile[originalKey] = nil end -- remove from old key
	local key = table.concat(prefix, " + ")
	while snippetsInFile[key] ~= nil do -- ensure new key is unique
		key = key .. "-1"
	end
	snippetsInFile[key] = snip -- insert at new key

	-- write & notify
	local success = rw.writeAndFormatSnippetFile(filepath, snippetsInFile)
	if success then
		local snipName = u.snipDisplayName(snip)
		local action = isNewSnippet and "created" or "updated"
		u.notify(("%q %s."):format(snipName, action))
	end
end

--------------------------------------------------------------------------------
return M
