local rw = require("scissors.read-write-operations")
local config = require("scissors.config").config

local M = {}
--------------------------------------------------------------------------------

-- DOCS https://code.visualstudio.com/api/language-extensions/snippet-guide

---@alias packageJson { contributes: { snippets: snippetFileMetadata[] } }

---@class (exact) snippetFileMetadata
---@field language string|string[]
---@field path string

--------------------------------------------------------------------------------

---@param pathOfSnippetFile string
---@return string|false filetype
---@nodiscard
function M.determineFileType(pathOfSnippetFile)
	-- PRIMARY METHOD: read `package.json`
	local relPathOfSnipFile = pathOfSnippetFile:sub(#config.snippetDir + 2)
	local packageJson = rw.readAndParseJson(config.snippetDir .. "/package.json")
	---@cast packageJson packageJson
	local snipFilesInfo = packageJson.contributes.snippets
	local fileMetadata = vim.tbl_filter(
		function(info) return info.path:gsub("^%.?/", "") == relPathOfSnipFile end,
		snipFilesInfo
	)
	if fileMetadata[1] then
		local lang = fileMetadata[1].language
		if type(lang) == "string" then lang = { lang } end
		lang = vim.tbl_filter(function(l) return l ~= "global" and l ~= "all" end, lang)
		if lang[1] then return lang[1] end
	end

	-- FALLBACK #1: filename is filetype
	local filename = vim.fs.basename(pathOfSnippetFile):gsub("%.json$", "")
	local allKnownFts = vim.fn.getcompletion("", "filetype")
	if vim.tbl_contains(allKnownFts, filename) then return filename end

	-- FALLBACK #2: filename is extension
	local matchedFt = vim.filetype.match { filename = "dummy." .. filename }
	if matchedFt then return matchedFt end

	return false
end

--------------------------------------------------------------------------------
return M
