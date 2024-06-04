<!-- LTeX: enabled=false -->
# nvim-scissors ✂️
<!-- LTeX: enabled=true -->
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-scissors">
<img alt="badge" src="https://dotfyle.com/plugins/chrisgrieser/nvim-scissors/shield"/></a>

Automagical editing and creation of snippets.

<https://github.com/chrisgrieser/nvim-scissors/assets/73286100/c620958a-eef6-46c2-957a-8504733e0312>

<https://github.com/chrisgrieser/nvim-scissors/assets/73286100/de544b7e-20c3-4bec-b7aa-cbaaacca09ca>

## Table of Contents

<!-- toc -->

- [Features](#features)
- [Rationale](#rationale)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Cookbook & FAQ](#cookbook--faq)
	* [Introduction to the VSCode-style snippet format](#introduction-to-the-vscode-style-snippet-format)
	* [Variables and Tabstops](#variables-and-tabstops)
	* [Version Controlling Snippets: JSON-formatting](#version-controlling-snippets-json-formatting)
	* [Snippets on Visual Selection](#snippets-on-visual-selection)
	* [`friendly-snippets`](#friendly-snippets)
	* [Auto-triggered Snippets](#auto-triggered-snippets)
- [Credits](#credits)

<!-- tocstop -->

## Features
- Add new snippets, edit snippets, or delete snippets on the fly.
- Syntax highlighting while you edit the snippet. Includes highlighting of
  tokens like `$0` or `${2:foobar}`.
- Automagical conversion from buffer text to JSON string (quotes are escaped, etc.).
- Intuitive UI for editing the snippet, dynamically adapting the number of
  prefixes.
- Hot-reloading of the new/edited snippet.
- JSON-formatting and sorting of the snippet file after updating, using `yq` or
  `jq`. (Optional, but [useful when version-controlling your snippet collection](#version-controlling-snippets-json-formatting).)
- Snippet/file
  selection via `telescope` or `vim.ui.select`.
- Automatic bootstrapping of the snippet folder, if it is empty or missing a
  `package.json`.
- Supports only [VSCode-style snippets](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets).

> [!TIP]
> You can use
> [snippet-converter.nvim](https://github.com/smjonas/snippet-converter.nvim) to
> convert your snippets to the VSCode format.

## Rationale
- Regrettably, there are innumerable formats in which snippets can be saved. The
  closest thing to a standard is the [VSCode snippet
  format](https://code.visualstudio.com/docs/editor/userdefinedsnippets). For
  portability, easier sharing, and to future-proof your snippet collection, it
  can make sense to save your snippets in that format.
- Most notably, the VSCode format is used by plugins like
  [friendly-snippets](https://github.com/rafamadriz/friendly-snippets) and
  supported by [LuaSnip](https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#vs-code).
- However, the snippets are stored as JSON files, which are a pain to modify
  manually. This plugin aims to alleviate that pain by automagically writing
  the JSON for you.

## Requirements
- nvim 0.10
- Snippets saved in the [VSCode-style snippet format](#example-for-the-vscode-style-snippet-format).
- [Telescope](https://github.com/nvim-telescope/telescope.nvim) OR ([dressing.nvim](http://github.com/stevearc/dressing.nvim) and
  [fzf-lua](https://github.com/ibhagwan/fzf-lua)).
- A snippet engine that can load VSCode-style snippets, such as
  [LuaSnip](https://github.com/L3MON4D3/LuaSnip) or
  [nvim-snippets](https://github.com/garymjr/nvim-snippets).

## Installation

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-scissors",
	dependencies = { "nvim-telescope/telescope.nvim", "L3MON4D3/LuaSnip" }, 
	opts = {
		snippetDir = "path/to/your/snippetFolder",
	} 
},

-- packer
use {
	"chrisgrieser/nvim-scissors",
	dependencies = { "nvim-telescope/telescope.nvim", "L3MON4D3/LuaSnip" }, 
	config = function()
		require("scissors").setup ({
			snippetDir = "path/to/your/snippetFolder",
		})
	end,
}
```

If you use `LuaSnip`, load the snippets in your `snippetDir` with:

```lua
require("luasnip.loaders.from_vscode").lazy_load { paths = { "path/to/your/snippetFolder" } }
```

If you are using `nvim-snippets`, set its `search_path` setting to the same path
as the `snippetDir` from `nvim-scissors`.

## Usage
The plugin provides two commands, `:ScissorsAddNewSnippet` and
`:ScissorsEditSnippet`. You can pass a range to `:ScissorsAddSnippet` command to
prefill snippet body (for example `:'<,'>ScissorsAddSnippet` or `:3ScissorsAddSnippet`).

The plugin also provides two lua functions `addNewSnippet` and `editSnippet`,
which you can use to directly create keymaps:

```lua
vim.keymap.set("n", "<leader>se", function() require("scissors").editSnippet() end)

-- When used in visual mode prefills the selection as body.
vim.keymap.set({ "n", "x" }, "<leader>sa", function() require("scissors").addNewSnippet() end)
```

> [!TIP]
> A quick method for creating a new snippet that is similar to an existing
> snippet is to search for a snippet via `editSnippet`, and then use the
> `duplicateSnippet` command (default keymap: `<C-d>`).

The popup intelligently adapts to changes in the prefix area: Each line
represents one prefix, and creating or removing lines thus changes
the number of prefixes. ("Prefix" is how trigger words are referred to in the
VSCode format.)

<img alt="Showcase prefix change" width=70% src="https://github.com/chrisgrieser/nvim-scissors/assets/73286100/d54f96c2-6751-46e9-9185-77b63eb2664a">

## Configuration
The `.setup()` call is optional.

```lua
-- default settings
require("scissors").setup {
	snippetDir = vim.fn.stdpath("config") .. "/snippets",
	editSnippetPopup = {
		height = 0.4, -- relative to the window, number between 0 and 1
		width = 0.6,
		border = "rounded",
		keymaps = {
			cancel = "q",
			saveChanges = "<CR>", -- alternatively, can also use `:w`
			goBackToSearch = "<BS>",
			deleteSnippet = "<C-BS>",
			duplicateSnippet = "<C-d>",
			openInFile = "<C-o>",
			insertNextToken = "<C-t>", -- insert & normal mode
			jumpBetweenBodyAndPrefix = "<C-Tab>", -- insert & normal mode
		},
	},
	telescope = {
		-- By default, the query only searches snippet prefixes. Set this to
		-- `true` to also search the body of the snippets.
		alsoSearchSnippetBody = false,
	},
	-- `none` writes as a minified json file using `vim.encode.json`.
	-- `yq`/`jq` ensure formatted & sorted json files, which is relevant when
	-- you version control your snippets.
	jsonFormatter = "none", -- "yq"|"jq"|"none"
}
```

> [!TIP]
> `vim.fn.stdpath("config")` returns the path to your nvim config.

## Cookbook & FAQ

### Introduction to the VSCode-style snippet format
This plugin requires that you have a valid VSCode snippet folder. In addition to
saving the snippets in the required JSON format, there must also be a
`package.json` at the root of the snippet folder, specifying which files are
should be used for which languages.

Example file structure inside the `snippetDir`:

```txt
.
├── package.json
├── python.json
├── project-specific
│   └── nvim-lua.json
├── javascript.json
└── allFiletypes.json
```

Example `package.json`:

```json
{
	"contributes": {
		"snippets": [
			{
				"language": "python",
				"path": "./python.json"
			},
			{
				"language": "lua",
				"path": "./project-specific/nvim-lua.json"
			},
			{
				"language": ["javascript", "typescript"],
				"path": "./javascript.json"
			},
			{
				"language": "all",
				"path": "./allFiletypes.json"
			}
		]
	},
	"name": "my-snippets"
}
```

> [!NOTE]
> The special filetype `all` enables the snippets globally, regardless of
> filetype.

Example snippet file (here: `nvim-lua.json`):

```json
{
  "autocmd (Filetype)": {
    "body": [
      "vim.api.nvim_create_autocmd(\"FileType\", {",
      "\tpattern = \"${1:ft}\",",
      "\tcallback = function()",
      "\t\t$0",
      "\tend,",
      "})"
    ],
    "prefix": "autocmd (Filetype)"
  },
  "file exists": {
    "body": "local fileExists = vim.uv.fs_stat(\"${1:filepath}\") ~= nil",
    "prefix": "file exists"
  },
}
```

For details, read the official VSCode snippet documentation:
- [Snippet file specification](https://code.visualstudio.com/docs/editor/userdefinedsnippets)
- [`package.json` specification](https://code.visualstudio.com/api/language-extensions/snippet-guide)
- [LuaSnip-specific additions to the format](https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#vs-code)

### Variables and Tabstops
- There are various variables you can use, such as `$TM_FILENAME` or
  `$LINE_COMMENT`. [See here for a full list of
  variables](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_variables).
- [Tabstops](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_tabstops)
  are denoted by `$1`, `$2`, `$3`, with `$0` being the last tabstop. They
  support placeholders such `${1:foobar}`.

> [!TIP]
> Due to the use of `$` in the snippet syntax, any *literal* `$` needs to be
> escaped as `\$`.

### Version Controlling Snippets: JSON-formatting
This plugin writes JSON files via `vim.encode.json()`. That method saves
the file in minified form, and does not have a
deterministic order of dictionary keys.

Both, minification, and unstable key order, are a problem if you
version-control your snippet collection. To solve this issue, `nvim-scissors`
can optionally unminify and sort the JSON files via `yq` or `jq` after updating
a snippet. (Both are also available via
[mason.nvim](https://github.com/williamboman/mason.nvim).)

It is recommended to run `yq`/`jq` once on all files in your snippet
collection, since the first time you edit a file, you would still get a large diff
from the initial sorting. You can do so with `yq` using this command:

```bash
cd "/your/snippet/dir"
fd ".*\.json" | xargs -I {} yq --inplace --output-format=json "sort_keys(..)" {}
```

How to do the same with `jq` is left as an exercise to the reader.

### Snippets on visual selections
With `Luasnip`, this is an opt-in feature, enabled via:

```lua
require("luasnip").setup {
	store_selection_keys = "<Tab>",
}
```

In your VSCode-style snippet, use the token `$TM_SELECTED_TEXT` at the location
where you want the selection to be inserted. (It's roughly the equivalent of
`LS_SELECT_RAW` in the `Luasnip` syntax.)

Then, in visual mode, press the key from `store_selection_keys`. The selection
disappears, and you are put in insert mode. The next snippet you now trigger
is going to have `$TM_SELECTED_TEXT` replaced with your selection.

### `friendly-snippets`
Even though the snippets from the [friendly-snippets](https://github.com/rafamadriz/friendly-snippets)
repository are written in the VSCode-style format, editing them directly is not
supported. The reason being that any changes made would be overwritten as soon
as the `friendly-snippets` repository is updated (which happens fairly
regularly). Unfortunately, there is little `nvim-scissors` can do about that.

What you can do, however, is to copy individual snippets files from the
`friendly-snippets` repository into your own snippet folder, and edit them there.

### Auto-triggered Snippets
While the VSCode snippet format does not support auto-triggered snippets,
`LuaSnip` allows you to [specify auto-triggering in the VSCode-style JSON
files by adding the `luasnip` key](https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#vs-code).

`nvim-scissors` does not touch any keys other than `prefix` and `body` in the
JSON files, so any additions via the `luasnip` key are preserved.

> [!TIP]
> You can use the `openInFile` keymap to directory open JSON file at the
> snippet's location to make edits there easier.

<!-- vale Google.FirstPerson = NO -->
## Credits
In my day job, I am a sociologist studying the social mechanisms underlying the
digital economy. For my PhD project, I investigate the governance of the app
economy and how software ecosystems manage the tension between innovation and
compatibility. If you are interested in this subject, feel free to get in touch.

I also occasionally blog about vim: [Nano Tips for Vim](https://nanotipsforvim.prose.sh)

- [Academic Website](https://chris-grieser.de/)
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
