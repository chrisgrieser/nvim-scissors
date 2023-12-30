local M = {}

local config = require("scissors.config").config
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@param path string
local function reloadSnippetFile(path)
	if not config.autoReload then return end

	-- LuaSnip https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
	local ok, luasnipLoaders = pcall(require, "luasnip.loaders")
	if ok and luasnipLoaders then luasnipLoaders.reload_file(path) end
end

---@param filepath string
---@param snippetsInFile snippetObj[]
---@return boolean success
---@nodiscard
local function writeAndFormatSnippetFile(filepath, snippetsInFile)
	local ok, jsonStr = pcall(vim.json.encode, snippetsInFile)
	assert(ok and jsonStr, "Could not encode JSON.")

	-- FORMAT
	-- INFO sorting via `yq` or `jq` is necessary, since `vim.json.encode`
	-- does not ensure a stable order of keys in the written JSON.
	if config.jsonFormatter ~= "none" then
		local cmds = {
			-- DOCS https://mikefarah.gitbook.io/yq/operators/sort-keys
			yq = { "yq", "--prettyPrint", "--output-format=json", "--no-colors", "sort_keys(..)" },
			-- DOCS https://jqlang.github.io/jq/manual/#invoking-jq
			jq = { "jq", "--sort-keys", "--monochrome-output" },
		}
		jsonStr = vim.fn.system(cmds[config.jsonFormatter], jsonStr)
		assert(vim.v.shell_error == 0, "JSON formatting exited with " .. vim.v.shell_error)
	end

	-- WRITE
	local file, _ = io.open(filepath, "w")
	assert(file, "Could not write to " .. filepath)
	file:write(jsonStr)
	file:close()

	-- RELOAD
	if config.autoReload then reloadSnippetFile(filepath) end

	return true
end

--------------------------------------------------------------------------------

---@param path string
---@return table
function M.readAndParseJson(path)
	local name = vim.fs.basename(path)
	local file, _ = io.open(path, "r")
	assert(file, name .. " could not be read")
	local content = file:read("*a")
	file:close()
	local ok, json = pcall(vim.json.decode, content) ---@cast json table
	if not ok then
		u.notify("Could not parse " .. name, "warn")
		return {}
	end
	return json
end

---@param snip snippetObj snippet to update/create
---@param editedLines string[]
function M.updateSnippetFile(snip, editedLines)
	local snippetsInFile = M.readAndParseJson(snip.fullPath)
	local filepath = snip.fullPath

	-- determine prefix & body
	local numOfPrefixes = type(snip.prefix) == "string" and 1 or #snip.prefix
	local prefix = vim.list_slice(editedLines, 1, numOfPrefixes)
	local body = vim.list_slice(editedLines, numOfPrefixes + 1, #editedLines)

	-- LINT/VALIDATE PREFIX & BODY
	-- trim (only trailing for body, since leading there is indentation)
	prefix = vim.tbl_map(function(line) return vim.trim(line) end, prefix)
	body = vim.tbl_map(function(line) return line:gsub("%s+$", "") end, body)
	-- remove deleted prefixes
	prefix = vim.tbl_filter(function(line) return line ~= "" end, prefix)
	if #prefix == 0 then
		u.notify("Prefix is empty. No changes made.", "warn")
		return
	end
	-- trim trailing empty lines from body
	while body[#body] == "" do
		table.remove(body)
		if #body == 0 then
			u.notify("Body is empty. No changes made.", "warn")
			return
		end
	end

	-- new snippet: key = prefix
	local isNewSnippet = snip.originalKey == nil
	local key = isNewSnippet and prefix[1] or snip.originalKey
	assert(key, "Snippet key missing")
	-- ensure key is unique
	while isNewSnippet and snippetsInFile[key] ~= nil do
		key = key .. "_1"
	end

	-- update snipObj
	snip.originalKey = nil -- delete key set by this plugin
	snip.fullPath = nil -- delete key set by this plugin
	snip.body = #body == 1 and body[1] or body
	snip.prefix = #prefix == 1 and prefix[1] or prefix
	snippetsInFile[key] = snip

	-- write & notify
	local success = writeAndFormatSnippetFile(filepath, snippetsInFile)
	if success then
		local displayName = #key > 20 and key:sub(1, 20) .. "…" or key
		local action = isNewSnippet and "created" or "updated"
		u.notify(("%q %s."):format(displayName, action))
	end
end

---@param snip snippetObj
function M.deleteSnippet(snip)
	local key = snip.originalKey
	assert(key)
	local snippetsInFile = M.readAndParseJson(snip.fullPath)
	snippetsInFile[key] = nil -- = delete

	local success = writeAndFormatSnippetFile(snip.fullPath, snippetsInFile)
	if success then
		local displayName = #key > 20 and key:sub(1, 20) .. "…" or key
		u.notify(("%q deleted."):format(displayName))
	end
end
--------------------------------------------------------------------------------
return M
