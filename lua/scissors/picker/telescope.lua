-- DOCS https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md
--------------------------------------------------------------------------------
local M = {}

local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")

local edit = require("scissors.edit-popup")
--------------------------------------------------------------------------------

---@param snippets SnippetObj[] entries
---@param formatter function(SnippetObj): string formats SnippetObj into display text
---@param prompt string
function M.selectSnippet(snippets, formatter, prompt)
	pickers
		.new({}, {
			prompt_title = prompt:gsub(":$", ""),
			sorter = conf.generic_sorter {},
			finder = finders.new_table {
				results = snippets,
				entry_maker = function(snip)
					return {
						value = snip,
						display = formatter(snip),
						ordinal = formatter(snip),
					}
				end,
			},
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local snip = action_state.get_selected_entry().value
					edit.editInPopup(snip, "update")
				end)
				return true
			end,
		})
		:find()
end

--------------------------------------------------------------------------------

---@param files snipFile[]
---@param formatter function(snipFile): string
---@param prompt string
---@param bodyPrefill string[] for the new snippet
function M.addSnippet(files, formatter, prompt, bodyPrefill)
	pickers
		.new({}, {
			prompt_title = prompt:gsub(":$", ""),
			sorter = conf.generic_sorter {},
			finder = finders.new_table {
				results = files,
				entry_maker = function(snip)
					return {
						value = snip,
						display = formatter(snip),
						ordinal = formatter(snip),
					}
				end,
			},
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local filepath = action_state.get_selected_entry().value
					edit.createNewSnipAndEdit(filepath, bodyPrefill)
				end)
				return true
			end,
		})
		:find()
end

--------------------------------------------------------------------------------
return M
