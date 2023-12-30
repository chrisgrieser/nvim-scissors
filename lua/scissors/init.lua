local M = {}

local setup = require("scissors.config").setupPlugin
local config = require("scissors.config").config
local editPopup = require("scissors.edit-popup")
local rw = require("scissors.read-write-operations")
local u = require("scissors.utils")

---@return boolean?
---@nodiscard
local function snippetDirExists()
	local stat = vim.loop.fs_stat(config.snippetDir)
	local exists = stat and stat.type == "directory"
	if not exists then u.notify("Snippet directory does not exist: " .. config.snippetDir, "error") end
	return exists
end

--------------------------------------------------------------------------------

---@param userConfig? pluginConfig
function M.setup(userConfig) setup(userConfig or {}) end

function M.editSnippet()
	if not snippetDirExists() then return end

	-- get all snippets
	local allSnippets = {} ---@type snippetObj[]
	for name, _ in vim.fs.dir(config.snippetDir, { depth = 3 }) do
		if name:find("%.jsonc?$") and name ~= "package.json" then
			local filepath = config.snippetDir .. "/" .. name
			local snippetsInFileDict = rw.readAndParseJson(filepath)

			-- convert dictionary to array for `vim.ui.select`
			local snippetsInFileList = {} ---@type snippetObj[]
			for key, snip in pairs(snippetsInFileDict) do
				snip.fullPath = filepath
				snip.originalKey = key
				table.insert(snippetsInFileList, snip)
			end
			vim.list_extend(allSnippets, snippetsInFileList)
		end
	end

	-- let user select
	vim.ui.select(allSnippets, {
		prompt = "Select snippet:",
		format_item = function(item)
			local snipname = item.prefix[1] or item.prefix
			local filename = vim.fs.basename(item.fullPath):gsub("%.json$", "")
			return ("%s\t\t[%s]"):format(snipname, filename)
		end,
		kind = "nvim-scissors.snippetSearch",
	}, function(snip)
		if not snip then return end
		editPopup.editInPopup(snip, "update")
	end)
end

function M.addNewSnippet()
	if not snippetDirExists() then return end

	-- get all snippets JSON files
	local jsonFiles = {}
	for name, _ in vim.fs.dir(config.snippetDir, { depth = 3 }) do
		if name:find("%.json$") and name ~= "package.json" then table.insert(jsonFiles, name) end
	end

	-- let user select
	vim.ui.select(jsonFiles, {
		prompt = "Select file for new snippet:",
		format_item = function(item) return item:gsub("%.json$", "") end,
		kind = "nvim-scissors.fileSelect",
	}, function(file)
		if not file then return end

		---@type snippetObj
		local snip = {
			fullPath = config.snippetDir .. "/" .. file,
			body = "",
			prefix = "",
		}
		editPopup.editInPopup(snip, "new")
	end)
end

--------------------------------------------------------------------------------
return M
