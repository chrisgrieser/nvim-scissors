vim.api.nvim_create_user_command(
	"ScissorsAddSnippet",
	function(args) require("scissors").addNewSnippet(args) end,
	{ desc = "Add new snippet", range = true }
)

vim.api.nvim_create_user_command(
	"ScissorsEditSnippet",
	function() require("scissors").editSnippet() end,
	{ desc = "Edit existing snippet" }
)
