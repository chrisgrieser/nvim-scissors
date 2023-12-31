local M = {}
--------------------------------------------------------------------------------

---@class SnippetObj used by this plugin
---@field fullPath string (key only set by this plugin)
---@field originalKey? string if not set, is a new snippet (key only set by this plugin)
---@field prefix string[] -- VS Code allows single string, but this plugin converts to array on read
---@field body string[] -- VS Code allows single string, but this plugin converts to array on read
---@field description? string

-- https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets
---@class VSCodeSnippet
---@field prefix string|string[]
---@field body string|string[]
---@field description? string

---@alias VSCodeSnippetDict table<string, VSCodeSnippet>

--------------------------------------------------------------------------------

---1. convert dictionary to array for `vim.ui.select`
---2. make body & prefix consistent array for nvim-api functions
---3. inject filepath into the snippet for convenience later on
---@param vscodeJson VSCodeSnippetDict
---@return SnippetObj[]
function M.restructureVsCodeObj(vscodeJson, filepath)
	local snippetsInFileList = {} ---@type SnippetObj[]

	-- convert dictionary to array
	for key, snip in pairs(vscodeJson) do
		---@diagnostic disable-next-line: cast-type-mismatch we are converting it here!
		---@cast snip SnippetObj
		snip.fullPath = filepath
		snip.originalKey = key
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

--------------------------------------------------------------------------------
return M
