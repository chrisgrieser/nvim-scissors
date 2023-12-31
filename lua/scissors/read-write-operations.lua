local M = {}

local config = require("scissors.config").config
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---currently only supports luasnip
---@param path string
local function reloadSnippetFile(path)
	-- LuaSnip https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
	local ok, luasnipLoaders = pcall(require, "luasnip.loaders")
	if ok and luasnipLoaders then luasnipLoaders.reload_file(path) end
end

--------------------------------------------------------------------------------

---@param path string
---@return table<string, object>
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

---@param filepath string
---@param snippetsInFile snippetObj[]
---@return boolean success
---@nodiscard
function M.writeAndFormatSnippetFile(filepath, snippetsInFile)
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
	reloadSnippetFile(filepath)

	return true
end

---@param snip snippetObj
function M.deleteSnippet(snip)
	local key = snip.originalKey
	assert(key)
	local snippetsInFile = M.readAndParseJson(snip.fullPath)
	snippetsInFile[key] = nil -- = delete

	local success = M.writeAndFormatSnippetFile(snip.fullPath, snippetsInFile)
	if success then
		local displayName = #key > 20 and key:sub(1, 20) .. "…" or key
		u.notify(("%q deleted."):format(displayName))
	end
end
--------------------------------------------------------------------------------
return M
