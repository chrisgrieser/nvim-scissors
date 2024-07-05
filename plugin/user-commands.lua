vim.api.nvim_create_user_command(
	"ScissorsAddNewSnippet",
	function(args) require("scissors").addNewSnippet(args) end,
	{ desc = "Add new snippet.", range = true }
)

vim.api.nvim_create_user_command(
	"ScissorsEditSnippet",
	function() require("scissors").editSnippet() end,
	{ desc = "Edit existing snippet." }
)

vim.api.nvim_create_user_command(
	"ScissorsCreateSnippetsForSnippetVars",
	function() require("scissors.vscode-format.snippet-variables").createSnippetFile() end,
	{ desc = "Create snippets for VSCode snippet variables." }
)
