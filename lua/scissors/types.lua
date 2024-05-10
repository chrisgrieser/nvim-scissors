
---@alias snipFile {path: string, ft: string}

---@class (exact) snippetFileMetadata
---@field language string|string[]
---@field path string

---DOCS https://code.visualstudio.com/api/language-extensions/snippet-guide
---@alias packageJson { contributes: { snippets: snippetFileMetadata[] } }

---@class SnippetObj used by this plugin
---@field fullPath string (key only set by this plugin)
---@field filetype string (key only set by this plugin)
---@field originalKey? string if not set, is a new snippet (key only set by this plugin)
---@field prefix string[] -- VS Code allows single string, but this plugin converts to array on read
---@field body string[] -- VS Code allows single string, but this plugin converts to array on read
---@field description? string

---DOCS https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets
---@alias VSCodeSnippetDict table<string, VSCodeSnippet>

---@class VSCodeSnippet
---@field prefix string|string[]
---@field body string|string[]
---@field description? string
