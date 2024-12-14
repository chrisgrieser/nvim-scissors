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

---@param snippets Scissors.SnippetObj[] entries
---@param prompt string
function M.selectSnippet(snippets, prompt)
	require("scissors.backdrop").setup("TelescopeResults")
	local conf = require("scissors.config").config.telescope

	pickers
		.new(conf.opts, {
			prompt_title = prompt:gsub(": ?$", ""),
			sorter = telescopeConf.generic_sorter(conf.opts),

			finder = finders.new_table {
				results = snippets,
				entry_maker = function(snip)
					local matcher = table.concat(snip.prefix, " ")
					if conf.alsoMatchBody then
						matcher = matcher .. " " .. table.concat(snip.body, "\n")
					end
					return {
						value = snip,
						display = function(entry)
							local _snip = entry.value
							local filename = vim.fs.basename(snip.fullPath):gsub("%.json$", "")
							local out = u.snipDisplayName(_snip) .. "\t" .. filename
							local highlights = {
								{ { #out - #filename, #out }, "TelescopeResultsComment" },
							}
							return out, highlights
						end,
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

					-- highlights of the snippet
					vim.bo[bufnr].filetype = snip.filetype
					vim.defer_fn(function() u.tokenHighlight(bufnr) end, 1)
				end,
			},

			attach_mappings = function(promptBufnr, _)
				actions.select_default:replace(function()
					actions.close(promptBufnr)
					local snip = actionState.get_selected_entry().value ---@type Scissors.SnippetObj
					edit.editInPopup(snip, "update")
				end)
				return true -- `true` = keeps default mappings from user
			end,
		})
		:find()
end

--------------------------------------------------------------------------------

---@param files Scissors.snipFile[]
---@param formatter fun(snipFile): string
---@param prompt string
---@param bodyPrefill string[] for the new snippet
function M.addSnippet(files, formatter, prompt, bodyPrefill)
	require("scissors.backdrop").setup("TelescopeResults")

	-- not using the telescope picker opts from the config, since in this case,
	-- we want a smaller window due to this picker only requiring filenames
	local telescopeOpts = {
		layout_strategy = "horizontal",
		layout_config = {
			horizontal = {
				width = { 0.5, max = 60 },
				height = { 0.4, min = 12 },
			},
		},
	}

	pickers
		.new(telescopeOpts, {
			prompt_title = prompt:gsub(": ?$", ""),
			sorter = telescopeConf.generic_sorter(telescopeOpts),

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
			attach_mappings = function(promptBufnr, _)
				actions.select_default:replace(function()
					actions.close(promptBufnr)
					local snipFile = actionState.get_selected_entry().value ---@type Scissors.snipFile snipFile
					edit.createNewSnipAndEdit(snipFile, bodyPrefill)
				end)
				return true -- `true` = keeps default mappings from user
			end,
		})
		:find()
end

--------------------------------------------------------------------------------
return M
