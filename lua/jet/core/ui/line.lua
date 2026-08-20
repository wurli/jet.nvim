---@alias jet.ui.line.parts { [1]: string, [2]?: jet.ui.line.extmark_shorthand, start_col?: integer, start_row?: integer }[]
---@alias jet.ui.line.extmark_shorthand string | vim.api.keyset.set_extmark | (string | vim.api.keyset.set_extmark)[]
---@alias jet.ui.line.extmark { mark: vim.api.keyset.set_extmark, start_col?: integer, start_row?: integer }}

---@class jet.ui.Line
---@field indent integer
---@field parts jet.ui.line.parts
---@field make_parts? fun(): jet.ui.line.parts Reset `parts`
---@field text string
---@field lnum? integer
---@field marks jet.ui.line.extmark[]
---@field data table<string, any>
---@field on_resolve? fun(self: jet.ui.Line)
local Line = {}
Line.__index = Line

---@param opts? Partial<jet.ui.Line>
---@param parts? jet.ui.line.parts | fun(): jet.ui.line.parts Reset `parts`
Line.new = function(opts, parts)
	opts = opts or {}
	parts = parts or {}
	local out = setmetatable({
		make_parts = type(parts) == "function" and parts or nil,
		indent = (opts.indent or 0) * 2,
		data = opts.data or {},
		parts = type(parts) == "table" and parts or {},
		on_resolve = opts.on_resolve,
		marks = {},
	}, Line)

	-- In this case we only need to resolve once
	if type(parts) == "table" then
		out:resolve()
	end

	return out
end

function Line:refresh()
	if self.make_parts then
		self.parts = self.make_parts()
		self:resolve()
	end
end

function Line:resolve()
	local text = string.rep(" ", self.indent)
	---@type jet.ui.line.extmark[]
	local marks = {}

	---@param x jet.ui.line.extmark_shorthand
	---@return vim.api.keyset.set_extmark[]
	local to_extmarks = function(x)
		x = vim.isarray(x) and x or { x } ---@type string[] | vim.api.keyset.set_extmark[]
		return vim.tbl_map(function(xi) return type(xi) == "string" and { hl_group = xi } or xi end, x)
	end

	for _, part in ipairs(self.parts) do
		local start_col = #text
		text = text .. part[1]
		for _, mark in ipairs(to_extmarks(part[2] or {})) do
			table.insert(marks, {
				mark = vim.tbl_extend("keep", mark, { end_col = #text }),
				start_col = part.start_col or start_col,
				start_row = part.start_row,
			})
		end
	end

	self.text = text
	self.marks = marks

	if self.on_resolve then
		self:on_resolve()
	end
end

return Line
