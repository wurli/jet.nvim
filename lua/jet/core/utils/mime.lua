local utils = require("jet.core.utils")

local M = {}

---E.g:
---* In:
---  `"text/plain"`
---* Out:
---  ```
---  { type = "text", subtype = "plain", params = {} }
---  ```
---
---* In:
---  `"application/vnd.jupyter.widget-view+json; version="2.0"; encoding=utf-8"`
---* Out:
---  ```
---  {
---      type = "application",
---      tree = "vnd",
---      subtype = "jupyter.widget-view",
---      suffix = "json",
---      params = { version = "2.0", encoding = "utf-8" },
---  }
---  ```
---
---@class jet.Mime
---@field type string
---@field subtype string
---@field tree? string
---@field suffix? string
---@field params table<string, string>

local mime_grammar ---@type vim.lpeg.Pattern?

---@param mime string
---@param quiet? boolean Suppress warnings on parse failures
---@return jet.Mime?
---@see https://en.wikipedia.org/wiki/Media_type
M.parse = function(mime, quiet)
	if not mime_grammar then
		mime_grammar = vim.re.compile([[
			mime    <- {| type '/' tree? subtype suffix? params |} !.
			type    <- {:type: token :}
			tree    <- {:tree: ('vnd' / 'prs' / 'x') :} '.'
			subtype <- {:subtype: { token ('.' token)* } :}
			suffix  <- '+' {:suffix: token :}
			params  <- {:params: {| param* |} :}
			param   <- space ';' space {| {:name: token :} '=' {:value: value :} |}
			token   <- [a-zA-Z0-9!#$&%^_-]+
			value   <- '"' { (!'"' .)* } '"' / { token }
			space   <- %s*
		]])
	end

	local parsed = mime_grammar:match(mime:lower())
	if not parsed then
		if not quiet then
			utils.log_warn("Failed to parse MIME type '%s'", mime)
		end
		return
	end

	local params = {}
	for _, p in ipairs(parsed.params) do
		params[p.name] = p.value
	end

	return {
		type = parsed.type,
		tree = parsed.tree,
		subtype = parsed.subtype,
		suffix = parsed.suffix,
		params = params,
	}
end

return M
