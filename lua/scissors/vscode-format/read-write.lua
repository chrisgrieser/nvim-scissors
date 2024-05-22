local M = {}

local config = require("scissors.config").config
local u = require("scissors.utils")
--------------------------------------------------------------------------------

local hasNotifiedOnRestartRequirement = false
---Currently only supports luasnip
---@param path string
local function reloadSnippetFile(path)
	local luasnipInstalled, luasnipLoaders = pcall(require, "luasnip.loaders")
	local nvimSnippetsInstalled, snippetUtils = pcall(require, "snippets.utils")
	if luasnipInstalled then
		luasnipLoaders.reload_file(path) -- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#loaders
	elseif nvimSnippetsInstalled then
		snippetUtils.reload_file(path) -- https://github.com/garymjr/nvim-snippets/issues/13#issuecomment-2125658450
	elseif not hasNotifiedOnRestartRequirement then
		local msg = "Restart nvim for changes to take effect.\n"
			.. "(Hot-reload is only supported for LuaSnip and nvim-snippets.)"
		u.notify(msg("info"))
		hasNotifiedOnRestartRequirement = true
	end
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
	local ok, json = pcall(vim.json.decode, content)
	if not (ok and json) then
		u.notify("Could not parse " .. name, "warn")
		return {}
	end
	return json
end

---@param filepath string
---@param text string
function M.writeFile(filepath, text)
	local file, _ = io.open(filepath, "w")
	assert(file, "Could not write to " .. filepath)
	file:write(text)
	file:close()
end

---@param filepath string
---@param jsonObj VSCodeSnippetDict|packageJson
---@return boolean success
function M.writeAndFormatSnippetFile(filepath, jsonObj)
	local ok, jsonStr = pcall(vim.json.encode, jsonObj)
	assert(ok and jsonStr, "Could not encode JSON.")

	-- FORMAT
	-- INFO sorting via `yq` or `jq` is necessary, since `vim.json.encode`
	-- does not ensure a stable order of keys in the written JSON.
	if config.jsonFormatter ~= "none" then
		local cmds = {
			-- DOCS https://mikefarah.gitbook.io/yq/operators/sort-keys
			yq = {
				"yq",
				"--prettyPrint",
				"--output-format=json",
				"--input-format=json", -- different parser, more stable https://github.com/mikefarah/yq/issues/1265#issuecomment-1200784274
				"--no-colors", -- safety net for some shells
				"sort_keys(..)",
			},
			-- DOCS https://jqlang.github.io/jq/manual/#invoking-jq
			jq = { "jq", "--sort-keys", "--monochrome-output" },
		}
		local result = vim.system(cmds[config.jsonFormatter], { stdin = jsonStr }):wait()
		if result.code ~= 0 then
			u.notify("JSON formatting failed: " .. result.stderr, "error")
			return false
		end
		jsonStr = result.stdout ---@cast jsonStr string
	end

	-- WRITE & RELOAD
	M.writeFile(filepath, jsonStr)
	if not vim.endswith(filepath, "package.json") then reloadSnippetFile(filepath) end

	return true
end

---@param snip SnippetObj
function M.deleteSnippet(snip)
	local key = snip.originalKey
	assert(key)
	local snippetsInFile = M.readAndParseJson(snip.fullPath) ---@cast snippetsInFile VSCodeSnippetDict
	snippetsInFile[key] = nil -- = delete

	local success = M.writeAndFormatSnippetFile(snip.fullPath, snippetsInFile)
	if success then
		local displayName = #key > 20 and key:sub(1, 20) .. "…" or key
		u.notify(("%q deleted."):format(displayName))
	end
end
--------------------------------------------------------------------------------
return M
