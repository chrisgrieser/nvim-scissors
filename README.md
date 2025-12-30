# nvim-scissors ✂️ <!-- rumdl-disable-line MD063 `nvim` lowercased -->
<a href="https://dotfyle.com/plugins/chrisgrieser/nvim-scissors">
<img alt="badge" src="https://dotfyle.com/plugins/chrisgrieser/nvim-scissors/shield"/></a>

Automagical editing and creation of snippets.

<https://github.com/chrisgrieser/nvim-scissors/assets/73286100/c620958a-eef6-46c2-957a-8504733e0312>

<https://github.com/chrisgrieser/nvim-scissors/assets/73286100/de544b7e-20c3-4bec-b7aa-cbaaacca09ca>

## Table of contents

<!-- toc -->

- [Features](#features)
- [Rationale](#rationale)
- [Requirements](#requirements)
- [Installation](#installation)
    - [Nvim-scissors](#nvim-scissors)
    - [Snippet engine setup](#snippet-engine-setup)
        - [LuaSnip](#luasnip)
        - [mini.snippets](#minisnippets)
        - [blink.cmp](#blinkcmp)
        - [basics-language-server](#basics-language-server)
        - [nvim-snippets](#nvim-snippets)
        - [vim-vsnip](#vim-vsnip)
        - [yasp.nvim](#yaspnvim)
- [Usage](#usage)
    - [Starting `nvim-scissors`](#starting-nvim-scissors)
    - [Editing snippets in the popup window](#editing-snippets-in-the-popup-window)
- [Configuration](#configuration)
- [Cookbook & FAQ](#cookbook--faq)
    - [Introduction to the VSCode-style snippet format](#introduction-to-the-vscode-style-snippet-format)
    - [Tabstops and variables](#tabstops-and-variables)
    - [Friendly-snippets](#friendly-snippets)
    - [Edit snippet title or description](#edit-snippet-title-or-description)
    - [Version controlling snippets & snippet file formatting](#version-controlling-snippets--snippet-file-formatting)
    - [Snippets on visual selections (`Luasnip` only)](#snippets-on-visual-selections-luasnip-only)
    - [Auto-triggered snippets (`Luasnip` only)](#auto-triggered-snippets-luasnip-only)
- [About the author](#about-the-author)

<!-- tocstop -->

## Features
- Add new snippets, edit snippets, or delete snippets on the fly.
- Syntax highlighting while you edit the snippet. Includes highlighting of
  tabstops and placeholders such as `$0`, `${2:foobar}`, or `$CLIPBOARD`
- Automagical conversion from buffer text to JSON string.
- Intuitive UI for editing the snippet, dynamically adapting the number of
  prefixes.
- Automatic hot-reloading of any changes, so you do not have to restart nvim for
  changes to take effect.
- Optional JSON-formatting and sorting of the snippet file. ([Useful when
  version-controlling your snippet
  collection](#version-controlling-snippets--snippet-file-formatting).)
- Snippet/file selection via `telescope`, `snacks`, or `vim.ui.select`.
- Automatic bootstrapping of the snippet folder or new snippet files if needed.
- Supports only [VSCode-style
  snippets](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets).

> [!TIP]
> You can use
> [snippet-converter.nvim](https://github.com/smjonas/snippet-converter.nvim) to
> convert your snippets to the VS Code format.

## Rationale
- The [VSCode snippet
  format](https://code.visualstudio.com/docs/editor/userdefinedsnippets) is the
  closest thing to a standard regarding snippets. It is used by
  [friendly-snippets](https://github.com/rafamadriz/friendly-snippets) and
  supported by most snippet engine plugins for nvim.
- However, VSCode snippets are stored as JSON, which are a pain to modify
  manually. This plugin alleviates that pain by automagically writing the JSON
  for you.

## Requirements
- nvim 0.10+
- Snippets saved in the [VSCode-style snippet
  format](#introduction-to-the-vscode-style-snippet-format).
- *Recommended*:
    - *ONE* of the following pickers:
        - [telescope](https://github.com/nvim-telescope/telescope.nvim)
        - [snacks.nvim](https://github.com/folke/snacks.nvim)
        - [fzf-lua](https://github.com/ibhagwan/fzf-lua)

        Without one of them, the plugin falls back to `vim.ui.select`, which still works but lacks
        search and snippet previews.

- A snippet engine that can load VS Code-style snippets, such as:
    - [LuaSnip](https://github.com/L3MON4D3/LuaSnip)
    - [mini.snippets](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-snippets.md)
    - [blink.cmp](https://github.com/Saghen/blink.cmp)
    - [basics-language-server](https://github.com/antonk52/basics-language-server/)
    - [nvim-snippets](https://github.com/garymjr/nvim-snippets)
    - [vim-vsnip](https://github.com/hrsh7th/vim-vsnip)
    - [yasp.nvim](https://github.com/DimitrisDimitropoulos/yasp.nvim)
- *Optional*: Treesitter parsers for the languages you want syntax highlighting
  for.

## Installation

<!-- rumdl-disable-next-line MD063 -->
### nvim-scissors

```lua
-- lazy.nvim
{
	"chrisgrieser/nvim-scissors",
	dependencies = "folke/snacks.nvim", -- either snacks, fzf-lua, telescope
	  -- dependencies = "ibhagwan/fzf-lua",
	  -- dependencies = "nvim-telescope/telescope.nvim",
	opts = {
		snippetDir = "path/to/your/snippetFolder",
	}
},

-- packer
use {
	"chrisgrieser/nvim-scissors",
	dependencies = "folke/snacks.nvim", -- either snacks, fzf-lua, telescope
	  -- dependencies = "ibhagwan/fzf-lua",
	  -- dependencies = "nvim-telescope/telescope.nvim",
	config = function()
		require("scissors").setup ({
			snippetDir = "path/to/your/snippetFolder",
		})
	end,
}
```

### Snippet engine setup
In addition, your snippet engine must point to the same snippet folder as
`nvim-scissors`:

> [!TIP]
> `vim.fn.stdpath("config")` returns the path to your nvim config.

<!-- rumdl-disable MD063 plugins names as headings here -->
#### LuaSnip

```lua
require("luasnip.loaders.from_vscode").lazy_load {
	paths = { "path/to/your/snippetFolder" },
}
```

#### mini.snippets
`mini.snippets` preferred snippet location is any `snippets/` directory in the
`runtimepath`. For manually maintained snippets the best location is the user
config directory, which requires the following `nvim-scissors` setup:

```lua
require("scissors").setup({
	snippetDir = vim.fn.stdpath("config") .. "/snippets",
})
```

The `mini.snippets` setup requires explicit definition of loaders. Following its
[Quickstart](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-snippets.md#quickstart)
guide should be enough to make it respect snippets from 'snippets/' directory
inside user config. **Note**: `nvim-scissors` works only with VS-Code-style
snippet files (not Lua files or JSON arrays), and requires a
[`package.json` for the VSCode
format](#introduction-to-the-vscode-style-snippet-format).

#### blink.cmp

```lua
require("blink.cmp").setup {
	sources = {
		providers = {
			snippets = {
				opts = {
					search_paths = { "path/to/your/snippetFolder" },
				},
			}
		}
	}
}
```

It is recommended to use the latest release of `blink.cmp` for hot-reloading to
work.

#### basics-language-server

```lua
require("lspconfig").basics_ls.setup({
    settings = {
        snippet = {
            enable = true,
            sources = { "path/to/your/snippetFolder" }
        },
    }
})
```

#### nvim-snippets

```lua
require("nvim-snippets").setup {
	search_paths = { "path/to/your/snippetFolder" },
}
```

#### vim-vsnip

```lua
vim.g.vsnip_snippet_dir = "path/to/your/snippetFolder"
-- OR
vim.g.vsnip_snippet_dirs = { "path/to/your/snippetFolder" }
```

#### yasp.nvim

```lua
require("yasp").setup {
	paths = {
		vim.fn.stdpath("config") .. "/snippets/package.json",
	},
	descs = { "user snippets" },
}
```

<!-- rumdl-enable MD063 -->
## Usage

### Starting `nvim-scissors`
The plugin provides two Lua functions, `.addNewSnippet()` and `.editSnippet()`:

```lua
vim.keymap.set(
	"n",
	"<leader>se",
	function() require("scissors").editSnippet() end,
	{ desc = "Snippet: Edit" }
)

-- when used in visual mode, prefills the selection as snippet body
vim.keymap.set(
	{ "n", "x" },
	"<leader>sa",
	function() require("scissors").addNewSnippet() end,
	{ desc = "Snippet: Add" }
)
```

You can also use `:ScissorsAddNewSnippet` and `:ScissorsEditSnippet` if you
prefer ex commands.

The `:ScissorsAddSnippet` ex command also accepts a range to prefill the snippet
body (for example `:'<,'> ScissorsAddNewSnippet` or `:3 ScissorsAddNewSnippet`).

### Editing snippets in the popup window
The popup is just one window, so you can move between the prefix area and the
body with `j` and `k` or any other movement command. ("Prefix" is how trigger
words are referred to in the VS Code format.)

Use `showHelp` (default keymap: `?`) to show a notification containing all
keymaps.

The popup intelligently adapts to changes in the prefix area: Each line
represents one prefix, and creating or removing lines in that area thus changes
the number of prefixes.

<img alt="Showcase prefix change" width=70% src="https://github.com/chrisgrieser/nvim-scissors/assets/73286100/d54f96c2-6751-46e9-9185-77b63eb2664a">

## Configuration
The `.setup()` call is optional.

```lua
-- default settings
require("scissors").setup {
	snippetDir = vim.fn.stdpath("config") .. "/snippets",
	editSnippetPopup = {
		height = 0.4, -- relative to the window, between 0-1
		width = 0.6,
		border = getBorder(), -- `vim.o.winborder` on nvim 0.11, otherwise "rounded"
		keymaps = {
			-- if not mentioned otherwise, the keymaps apply to normal mode
			cancel = "q",
			saveChanges = "<CR>", -- alternatively, can also use `:w`
			goBackToSearch = "<BS>",
			deleteSnippet = "<C-BS>",
			duplicateSnippet = "<C-d>",
			openInFile = "<C-o>",
			insertNextPlaceholder = "<C-p>", -- insert & normal mode
			showHelp = "?",
		},
	},

	snippetSelection = {
		picker = "auto", ---@type "auto"|"telescope"|"snacks"|"vim.ui.select"

		fzfLua = {
			-- same format as fzf_opts in `:h fzf-lua-customization`
			fzf_opts = {},

			-- suppress warnings from fzf-lua.
			-- This is true by default, since commonly-used fzf-lua presets
			-- create warnings due to border settings.
			silent = true,

			-- same format as winopts in `:h fzf-lua-customization`
			winopts = {
				preview = {
					hidden = false,
				},
			},
		},

		telescope = {
			-- By default, the query only searches snippet prefixes. Set this to
			-- `true` to also search the body of the snippets.
			alsoSearchSnippetBody = false,

			-- accepts the common telescope picker config
			opts = {
				layout_strategy = "horizontal",
				layout_config = {
					horizontal = { width = 0.9 },
					preview_width = 0.6,
				},
			},
		},

		-- `snacks` picker configurable via snacks config,
		-- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md
	},

	-- `none` writes as a minified json file using `vim.encode.json`.
	-- `yq`/`jq` ensure formatted & sorted json files, which is relevant when
	-- you version control your snippets. To use a custom formatter, set to a
	-- list of strings, which will then be passed to `vim.system()`.
	-- TIP: `jq` is already pre-installed on newer versions of macOS.
	---@type "yq"|"jq"|"none"|string[]
	jsonFormatter = "none",

	backdrop = {
		enabled = true,
		blend = 50, -- between 0-100
	},
	icons = {
		scissors = "󰩫",
	},
}
```

## Cookbook & FAQ

### Introduction to the VSCode-style snippet format
This plugin requires that you have a valid VS Code snippet folder. In addition
to saving the snippets in the required JSON format, there must also be a
`package.json` file at the root of the snippet folder, specifying which files
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

### Tabstops and variables
[Tabstops](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_tabstops)
are denoted by `$1`, `$2`, `$3`, etc., with `$0` being the last tabstop. They
support placeholders such as `${1:foobar}`.

> [!NOTE]
> Due to the use of `$` in the snippet syntax, any *literal* `$` needs to be
> escaped as `\$`.

Furthermore, there are various variables you can use, such as `$TM_FILENAME` or
`$LINE_COMMENT`. [See here for a full list of
variables](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_variables).

<!-- LTeX: enabled=false -->
### Friendly-snippets
<!-- LTeX: enabled=true -->
Even though the snippets from the [friendly-snippets](https://github.com/rafamadriz/friendly-snippets)
repository are written in the VS Code-style format, editing them directly is not
supported. The reason being that any changes made would be overwritten as soon
as the `friendly-snippets` repository is updated (which happens fairly
regularly). Unfortunately, there is little `nvim-scissors` can do about that.

What you can do, however, is to copy individual snippets files from the
`friendly-snippets` repository into your own snippet folder, and edit them
there.

### Edit snippet title or description
`nvim-scissors` only allows you to edit the snippet prefix and snippet body, to
keep the UI as simple as possible. For the few cases where you need to edit a
snippet's title or description, you can use the `openInFile` keymap and edit
them directly in the snippet file.

### Version controlling snippets & snippet file formatting
This plugin writes JSON files via `vim.encode.json()`. That method saves
the file in minified form and does not have a
deterministic order of dictionary keys.

Both, minification and unstable key order, are a problem if you
version-control your snippet collection. To solve this issue, `nvim-scissors`
lets you optionally unminify and sort the JSON files via `yq` or `jq` after
updating a snippet. (Both are also available via
[mason.nvim](https://github.com/williamboman/mason.nvim).)

It is recommended to run `yq`/`jq` once on all files in your snippet collection,
since the first time you edit a file, you would still get a large diff from the
initial sorting. You can do so with `yq` using this command:

```bash
cd "/your/snippet/dir"
find . -name "*.json" | xargs -I {} yq --inplace --output-format=json "sort_keys(..)" {}
```

How to do the same with `jq` is left as an exercise to the reader.

### Snippets on visual selections (`Luasnip` only)
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

### Auto-triggered snippets (`Luasnip` only)
While the VS Code snippet format does not support auto-triggered snippets,
`LuaSnip` allows you to [specify auto-triggering in the VSCode-style JSON
files by adding the `luasnip` key](https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#vs-code).

`nvim-scissors` does not touch any keys other than `prefix` and `body` in the
JSON files, so any additions like the `luasnip` key are preserved.

> [!TIP]
> You can use the `openInFile` keymap to directory open JSON file at the
> snippet's location to make edits there easier.

## About the author
In my day job, I am a sociologist studying the social mechanisms underlying the
digital economy. For my PhD project, I investigate the governance of the app
economy and how software ecosystems manage the tension between innovation and
compatibility. If you are interested in this subject, feel free to get in touch.

- [Website](https://chris-grieser.de/)
- [Mastodon](https://pkm.social/@pseudometa)
- [ResearchGate](https://www.researchgate.net/profile/Christopher-Grieser)
- [LinkedIn](https://www.linkedin.com/in/christopher-grieser-ba693b17a/)

<a href='https://ko-fi.com/Y8Y86SQ91' target='_blank'><img height='36'
style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3'
border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
