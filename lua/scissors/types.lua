---@meta

---@class Scissors.snipFile
---@field path string
---@field ft string
---@field fileIsNew? boolean

---DOCS https://code.visualstudio.com/api/language-extensions/snippet-guide
---@class Scissors.packageJson
---@field contributes { snippets: Scissors.snippetFileMetadata[] }

---@class (exact) Scissors.snippetFileMetadata
---@field language string|string[]
---@field path string


---@class (exact) Scissors.SnippetObj used by this plugin
---@field fullPath string (key only set by this plugin)
---@field filetype string (key only set by this plugin)
---@field originalKey? string if not set, is a new snippet (key only set by this plugin)
---@field prefix string[] -- VS Code allows single string, but this plugin converts to array on read
---@field body string[] -- VS Code allows single string, but this plugin converts to array on read
---@field description? string
---@field fileIsNew? boolean -- the file for the snippet is newly created

---DOCS https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets
---@alias VSCodeSnippetDict table<string, Scissors.VSCodeSnippet>

---@class (exact) Scissors.VSCodeSnippet
---@field prefix string|string[]
---@field body string|string[]
---@field description? string
