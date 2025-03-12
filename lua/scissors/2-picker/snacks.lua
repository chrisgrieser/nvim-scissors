-- DOCS https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#-module
--------------------------------------------------------------------------------
local M = {}

local edit = require("scissors.3-edit-popup")
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@param snippets Scissors.SnippetObj[]
---@return Scissors.SnacksObj[]
local function createSnacksItems(snippets)
	---@type Scissors.SnacksObj[]
	local items = {}
	for i, snip in ipairs(snippets) do
		local filename = vim.fs.basename(snip.fullPath):gsub("%.json$", "")
		local displayName = u.snipDisplayName(snip)
		local name = displayName .. "\t" .. filename

		table.insert(items, {
			idx = i,
			score = i,
			text = displayName .. " " .. table.concat(snip.body, "\n"),
			name = name,
			snippet = snip,
			displayName = displayName,
		})

		table.sort(items, function(a, b) return a.name < b.name end)
	end

	return items
end

---@param snippets Scissors.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	return require("snacks").picker {
		prompt = prompt,
		items = createSnacksItems(snippets),
		---@param item Scissors.SnacksObj
		format = function(item, _)
			local ret = {}
			ret[#ret + 1] = { item.displayName, "SnacksPickerFile" }
			ret[#ret + 1] = { " " }
			ret[#ret + 1] = { "[" .. item.snippet.filetype .. "]", "@comment" }
			return ret
		end,
		preview = function(ctx)
			local snip = ctx.item.snippet ---@type Scissors.SnippetObj
			local bufnr = ctx.buf ---@type number
			vim.bo[bufnr].modifiable = true
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, snip.body)
			vim.bo[bufnr].filetype = snip.filetype
			vim.defer_fn(function() u.tokenHighlight(bufnr) end, 1)
		end,
		---@param item Scissors.SnacksObj,
		confirm = function(picker, item)
			picker:close()
			if item then edit.editInPopup(item.snippet, "update") end
		end,
	}
end

--------------------------------------------------------------------------------
return M
