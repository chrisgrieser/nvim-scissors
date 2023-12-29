<!-- LTeX: enabled=false -->
# nvim-scissors ✂️
<!-- LTeX: enabled=true -->
<!-- TODO uncomment shields when available in dotfyle.com 
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-scissors">
<img alt="badge" src="https://dotfyle.com/plugins/chrisgrieser/nvim-scissors/shield"/></a>
-->

Automagical snippet management.

<!-- toc -->

- [Features](#features)
- [Rationale](#rationale)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Note on JSON-formatting](#note-on-json-formatting)
- [Credits](#credits)

<!-- tocstop -->

## Features
- ℹ️ Supports only [VSCode-style snippets (JSON files)](https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#vscode).
- Add new snippets, edit snippets, delete snippets.
- Automagical conversion from buffer text to JSON string (quotes are escaped, etc.)
- Syntax highlighting while you edit the snippet. Includes highlighting of
  tabstop tokens like `$0` or `${2:foobar}`.
- Auto-reloading of the new snippet (if using `LuaSnip`).
- JSON-formatting and sorting of the snippet file after updating, using `yq` or
  `jq` (Optional, but useful when version-controlling your snippet collection.)

> [!NOTE]
> This plugin only *manages* snippets. It does not provide a snippet *engine*
> and therefore does not expand snippets. Install a plugin like
> [LuaSnip](https://github.com/L3MON4D3/LuaSnip) for that.

## Rationale
- Regrettably, there are innumerable formats in which snippets can be saved. The
  only format which supported by many applications and somewhat comes close to
  being a standard is the [VSCode snippet
  format](https://code.visualstudio.com/docs/editor/userdefinedsnippets). For
  portability and to future-proof your snippet collection, it thus makes sense to
  save your snippets in that format.
- Most notably, the VSCode snippet format is used by plugins like
  [friendly-snippets](https://github.com/rafamadriz/friendly-snippets) and also
  supported by [LuaSnip](https://github.com/L3MON4D3/LuaSnip).
- However, the snippets are stored in JSON files, which are a pain to modify
  manually. This plugin aims to alleviate that pain by automagically writing
  the JSON for you.

> [!TIP]
> You can use
> [snippet-converter.nvim](https://github.com/smjonas/snippet-converter.nvim) to
> convert your snippets to different formats.

## Installation

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-scissors",
	opts = {
		snippetDir = "path/to/your/snippetFolder",
	} 
},

-- packer
use {
	"chrisgrieser/nvim-scissors",
	config = function()
		require("nvim-scissors").setup ({
			snippetDir = "path/to/your/snippetFolder",
		})
	end,
}
```

## Usage
The plugin provides two commands, `addNewSnippet` and `editSnippet`. Here is the
code to create keymaps for them:

```lua
vim.keymap.set(
	"n",
	"<leader>se",
	function() require("scissors").editSnippet() end,
	{ desc = " Edit Snippets" }
)
vim.keymap.set(
	"n",
	"<leader>sa",
	function() require("scissors").addNewSnippet() end,
	{ desc = " Add new snippet" }
)
```

## Configuration

The `.setup()` call is optional.

```lua
-- default settings
require("nvim-scissors").setup {
	snippetDir = vim.fn.stdpath("config") .. "/snippets",
	editSnippetPopup = {
		height = 0.4, -- between 0-1
		width = 0.6,
		border = "rounded",
		keymaps = {
			cancel = "q",
			saveChanges = "<CR>", -- normal mode
			delete = "<C-BS>",
			openInFile = "<C-o>",
		},
	},
	-- `none` writes as a minified json file using `:h vim.encode.json`.
	-- `yq` and `jq` ensure formatted & sorted json files, which is relevant when
	-- you are version control your snippets.
	jsonFormatter = "none", -- "yq"|"jq"|"none"

	-- on adding/editing a snippet, reload the snippet file. Currently only
	-- supports LuaSnip (PRs welcome)
	autoReload = true,
}
```

> [!TIP]
> `vim.fn.stdpath("config")` returns the path to your nvim config, so you do not
> need to the location of your snippet folder.

## Note on JSON-formatting
This plugin writes JSON files via `vim.encode.json`. This method always writes
the file in minified form, and also does not have a deterministic order of
dictionary keys. That means that the JSON file can have a different order of
keys before and after updating it via `nvim-scissors`.

Both, minification, and unstable key order are of course problem if you version-control
your snippet collection. To solve this problem, `nvim-scissors` can optionally
unminify and sort the JSON files after updating it via `yq` or `jq`. (Both are
also available via [mason.nvim](https://github.com/williamboman/mason.nvim).)

It is recommended to run `yq`/`jq` once on all files in your snippet
collection, since the first time you edit a file, you still get a large diff
from the initial sorting. You can do so with `yq` with this command:

```bash
cd "/your/snippet/dir"
fd ".*\.json" | xargs -I {} yq --inplace --output-format=json "sort_keys(..)" {}
```

(How to do the same with `jq` is left as an exercise to the reader. 🙂)

## Credits
<!-- vale Google.FirstPerson = NO -->
__About Me__  
In my day job, I am a sociologist studying the social mechanisms underlying the
digital economy. For my PhD project, I investigate the governance of the app
economy and how software ecosystems manage the tension between innovation and
compatibility. If you are interested in this subject, feel free to get in touch.

__Blog__  
I also occasionally blog about vim: [Nano Tips for Vim](https://nanotipsforvim.prose.sh)

__Profiles__  
- [reddit](https://www.reddit.com/user/pseudometapseudo)
- [Discord](https://discordapp.com/users/462774483044794368/)
- [Academic Website](https://chris-grieser.de/)
- [Twitter](https://twitter.com/pseudo_meta)
- [Mastodon](https://pkm.social/@pseudometa)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

<a href='https://ko-fi.com/Y8Y86SQ91' target='_blank'><img
	height='36'
	style='border:0px;height:36px;'
	src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3'
	border='0'
	alt='Buy Me a Coffee at ko-fi.com'
/></a>
