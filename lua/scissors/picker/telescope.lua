-- DOCS https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md
--------------------------------------------------------------------------------
local M = {}

local pickers = require("telescope.pickers")
local telescopeConf = require("telescope.config").values
local actionState = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")

local edit = require("scissors.edit-popup")
local u = require("scissors.utils")
--------------------------------------------------------------------------------

---@param snippets SnippetObj[] entries
---@param formatter function(SnippetObj): string formats SnippetObj into display text
---@param prompt string
function M.selectSnippet(snippets, formatter, prompt)
	local alsoMatchBody = require("scissors.config").config.telescope.alsoSearchSnippetBody

	-- HACK color parent as comment, see `snipDisplay` using `\t\t`
	-- TODO figure out coloring without using this autocmd
	vim.api.nvim_create_autocmd("FileType", {
		once = true,
		pattern = "TelescopeResults",
		callback = function(ctx)
			vim.api.nvim_buf_call(ctx.buf, function() vim.fn.matchadd("Comment", "\t\t.*$") end)
		end,
	})

	pickers
		.new({}, {
			prompt_title = prompt:gsub(": ?$", ""),
			sorter = telescopeConf.generic_sorter {},

			finder = finders.new_table {
				results = snippets,
				entry_maker = function(snip)
					local matcher = table.concat(snip.prefix, " ")
					if alsoMatchBody then matcher = matcher .. " " .. table.concat(snip.body, "\n") end
					return {
						value = snip,
						display = formatter(snip),
						ordinal = matcher,
					}
				end,
			},

			-- DOCS `:help telescope.previewers`
			previewer = previewers.new_buffer_previewer {
				dyn_title = function(_, entry)
					local snip = entry.value
					return u.snipDisplayName(snip)
				end,
				define_preview = function(self, entry)
					local snip = entry.value
					local bufnr = self.state.bufnr
					vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, snip.body)

					-- highlights
					vim.api.nvim_buf_set_option(bufnr, "filetype", snip.filetype)
					vim.defer_fn(function() u.tokenHighlight(bufnr) end, 1)
				end,
			},

			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local snip = actionState.get_selected_entry().value
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
			prompt_title = prompt:gsub(": ?$", ""),
			sorter = telescopeConf.generic_sorter {},

			layout_strategy = "horizontal",
			layout_config = {
				horizontal = {
					width = { 0.5, max = 60 },
					height = { 0.4, min = 12 },
				},
			},

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
					local snipFile = actionState.get_selected_entry().value ---@type snipFile snipFile
					edit.createNewSnipAndEdit(snipFile, bodyPrefill)
				end)
				return true
			end,
		})
		:find()
end

--------------------------------------------------------------------------------
return M
