-- DOCS https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#-module
--------------------------------------------------------------------------------
local M = {}

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
	end

	return items
end

---@param snippets Scissors.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	return require("snacks").picker {
		title = prompt:gsub(": ?", ""),
		items = createSnacksItems(snippets),

		format = function(item, _) ---@param item Scissors.SnacksObj
			return {
				{ item.displayName, "SnacksPickerFile" },
				{ " " },
				{ item.snippet.filetype, "Comment" },
			}
		end,

		preview = function(ctx)
			local snip = ctx.item.snippet ---@type Scissors.SnippetObj
			local bufnr = ctx.buf ---@type number

			vim.bo[bufnr].modifiable = true
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, snip.body)
			vim.bo[bufnr].modifiable = false

			vim.bo[bufnr].filetype = snip.filetype == "all" and "text" or snip.filetype
			vim.defer_fn(function() u.tokenHighlight(bufnr) end, 1)
		end,

		---@param item Scissors.SnacksObj,
		confirm = function(picker, item)
			picker:close()
			require("scissors.3-edit-popup").editInPopup(item.snippet, "update")
		end,
	}
end

--------------------------------------------------------------------------------
return M
