-- Functions for converting from/to the VSCode Snippet Format.
--------------------------------------------------------------------------------
local M = {}

local rw = require("scissors.vscode-format.read-write")
local u = require("scissors.utils")
local config = require("scissors.config").config
--------------------------------------------------------------------------------

---@param filetype "all"|string
---@return string[] absPathsOfSnipfileForFt
function M.getSnippetfilePathsForFt(filetype)
	local packageJson = rw.readAndParseJson(config.snippetDir .. "/package.json")
	---@cast packageJson Scissors.packageJson

	local snipFilesMetadata = packageJson.contributes.snippets
	local absPaths = {}

	for _, metadata in pairs(snipFilesMetadata) do
		local lang = metadata.language
		if type(lang) == "string" then lang = { lang } end
		if vim.tbl_contains(lang, filetype) then
			local absPath = config.snippetDir .. "/" .. metadata.path:gsub("^%.?/", "")
			table.insert(absPaths, absPath)
		end
	end
	return absPaths
end

---@param absPath string of snippet file
---@param filetype string filetype to assign to all snippets in the file
---@return Scissors.SnippetObj[]
---@nodiscard
function M.readVscodeSnippetFile(absPath, filetype)
	local vscodeJson = rw.readAndParseJson(absPath) ---@cast vscodeJson Scissors.VSCodeSnippetDict

	local snippetsInFileList = {} ---@type Scissors.SnippetObj[]

	-- convert dictionary to array for `vim.ui.select`
	for key, snip in pairs(vscodeJson) do
		---@diagnostic disable-next-line: cast-type-mismatch we are converting it here
		---@cast snip Scissors.SnippetObj
		snip.fullPath = absPath
		snip.originalKey = key
		snip.filetype = filetype
		table.insert(snippetsInFileList, snip)
	end

	-- VSCode allows body and prefix to be a string. Converts to array on
	-- read for consistent handling with nvim-api.
	for _, snip in ipairs(snippetsInFileList) do
		local rawPrefix = type(snip.prefix) == "string" and { snip.prefix } or snip.prefix
		local rawBody = type(snip.body) == "string" and { snip.body } or snip.body
		---@cast rawPrefix string[] -- ensured above
		---@cast rawBody string[] -- ensured above

		-- Strings can contain lines breaks, but nvim-api functions expect each
		-- string representing a single line, so we are converting them.
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

---@param snip Scissors.SnippetObj snippet to update/create
---@param changedSnippetLines string[]
---@param prefixCount number determining how many lines in the changes lines belong to the prefix
function M.updateSnippetInVscodeSnippetFile(snip, changedSnippetLines, prefixCount)
	local snippetsInFile = rw.readAndParseJson(snip.fullPath) ---@cast snippetsInFile Scissors.VSCodeSnippetDict

	local filepath = snip.fullPath
	local prefix = vim.list_slice(changedSnippetLines, 1, prefixCount)
	local body = vim.list_slice(changedSnippetLines, prefixCount + 1, #changedSnippetLines)
	local isNewSnippet = snip.originalKey == nil

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
	-- Auto-escape unescaped literal `$` in the body not used for tabstops or
	-- placeholders, since they make the vscode snippets invalid.
	-- Note: This does not affect placeholders such as `$foobar`, since those are
	-- valid in the VSCode. (Though they result in an empty string if not
	-- defined, so in most cases, the user still needs to escape them.)
	for i, line in ipairs(body) do
		body[i] = line
			:gsub("([^\\])%$([^%w{])", "%1\\$%2") -- middle of line
			:gsub("^%$([^%w{])", "\\$%1") -- beginning of line
			:gsub("([^\\])%$$", "%1\\$") -- end of line
	end

	-- VALIDATE
	if #body == 0 then
		u.notify("Body is empty. No changes made.", "warn")
		return
	end
	if #prefix == 0 then
		u.notify("Prefix is empty. No changes made.", "warn")
		return
	end

	-- convert snipObj to VSCodeSnippet
	local vsCodeSnip = vim.deepcopy(snip)
	---@diagnostic disable-next-line: cast-type-mismatch we are converting it here
	---@cast vsCodeSnip Scissors.VSCodeSnippet
	vsCodeSnip.prefix = #prefix == 1 and prefix[1] or prefix
	vsCodeSnip.body = #body == 1 and body[1] or body
	-- delete keys added by this plugin
	---@diagnostic disable: inject-field
	vsCodeSnip.fullPath = nil
	vsCodeSnip.filetype = nil
	vsCodeSnip.originalKey = nil
	vsCodeSnip.fileIsNew = nil
	---@diagnostic enable: inject-field

	-- insert item at new key for VSCode format
	local key = snip.originalKey
	if not key then
		key = table.concat(prefix, " + ")
		while snippetsInFile[key] ~= nil do -- ensure new key is unique
			key = key .. "-1"
		end
	end
	snippetsInFile[key] = vsCodeSnip

	-- write & notify
	local success = rw.writeAndFormatSnippetFile(filepath, snippetsInFile, snip.fileIsNew)
	if success then
		local snipName = u.snipDisplayName(vsCodeSnip)
		local action = isNewSnippet and "created" or "updated"
		u.notify(("%q %s."):format(snipName, action))
	end
end

--------------------------------------------------------------------------------
return M
