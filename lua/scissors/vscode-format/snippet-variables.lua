local M = {}
--------------------------------------------------------------------------------

-- https://code.visualstudio.com/docs/editor/userdefinedsnippets#_variables
M.vars = {
	"TM_SELECTED_TEXT",
	"TM_CURRENT_LINE",
	"TM_CURRENT_WORD",
	"TM_LINE_INDEX",
	"TM_LINE_NUMBER",
	"TM_FILENAME",
	"TM_FILENAME_BASE",
	"TM_DIRECTORY",
	"TM_FILEPATH",
	"CLIPBOARD",
	"CURRENT_YEAR",
	"CURRENT_YEAR_SHORT",
	"CURRENT_MONTH",
	"CURRENT_MONTH_NAME",
	"CURRENT_MONTH_NAME_SHORT",
	"CURRENT_DATE",
	"CURRENT_DAY_NAME",
	"CURRENT_DAY_NAME_SHORT",
	"CURRENT_HOUR",
	"CURRENT_MINUTE",
	"CURRENT_SECOND",
	"CURRENT_SECONDS_UNIX",
	"CURRENT_TIMEZONE_OFFSET",
	"RANDOM",
	"RANDOM_HEX",
	"UUID",
	"LINE_COMMENT",
	"BLOCK_COMMENT_START",
	"BLOCK_COMMENT_END",
}

function M.createSnippetFile()
	local vb = require("scissors.vscode-format.validate-bootstrap")
	local convert = require("scissors.vscode-format.convert-object")
	local u = require("scissors.utils")
	local pluginFiletype = require("scissors.config").pluginFiletype

	-- GUARD
	local snipFileForSnipVars = convert.getSnippetFilesForFt(pluginFiletype)
	if #snipFileForSnipVars > 0 then
		local filename = vim.fs.basename(snipFileForSnipVars[1])
		u.notify(("There already is a file %q."):format(filename), "warn")
		return
	end

	local json = {}
	for _, var in ipairs(M.vars) do
		json[var] = {
			prefix = "$" .. var,
			body = "\\$" .. var, -- needs to be escaped to not be interpreted as a variable itself
		}
	end
	vb.bootstrapSnippetFile(pluginFiletype, vim.json.encode(json))
	-- Cannot hotreload the new snippet file, since reloading the package.json is
	-- not supported by the reloading functions of the snippet engines.

	local filename = vim.fs.basename(pluginFiletype)
	local msg = ("Snippet file %q for VSCode variables created."):format(filename)
		.. "\n\nRestart nvim for this to take effect."
	u.notify(msg, "info")
end

--------------------------------------------------------------------------------
return M
