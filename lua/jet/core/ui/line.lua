---@alias jet.ui.line.parts { [1]: string, [2]?: jet.ui.line.extmark_shorthand, start_col?: integer, end_col?: integer }[]
---@alias jet.ui.line.extmark_shorthand string | vim.api.keyset.set_extmark | (string | vim.api.keyset.set_extmark)[]
---@alias jet.ui.line.extmark { [1]: integer, [2]: integer, [3]: vim.api.keyset.set_extmark }

---@class jet.ui.line
---@field indent integer
---@field timer? boolean
---@field on_refresh? fun(self: jet.ui.line) Called after `refresh` is called
---@field parts jet.ui.line.parts
---@field make_parts fun(): jet.ui.line.parts Reset `parts`
---@field text string
---@field lnum? integer
---@field marks jet.ui.line.extmark[]
---@field stopped boolean
---@field data table<string, any>
local Line = {}
Line.__index = Line

---@param opts? Partial<jet.ui.line>
---@param parts? jet.ui.line.parts | fun(): jet.ui.line.parts Reset `parts`
Line.new = function(opts, parts)
	opts = opts or {}
	parts = parts or {}
	return setmetatable({
		make_parts = type(parts) == "function" and parts or function() return parts end,
		indent = (opts.indent or 0) * 2,
		timer = opts.timer,
		data = opts.data or {},
		on_refresh = opts.on_refresh,
		parts = {},
		stopped = false,
	}, Line)
end

function Line:refresh()
	if self.stopped then
		return
	end
	self.parts = self.make_parts()
	self:resolve()
	if self.on_refresh then
		self:on_refresh()
	end
end

function Line:resolve()
	local text = string.rep(" ", self.indent)
	---@type jet.ui.line.extmark[]
	local marks = {}

	---@param x jet.ui.line.extmark_shorthand
	---@return vim.api.keyset.set_extmark[]
	local to_extmarks = function(x)
		if not vim.isarray(x) then
			x = { x }
		end
		---@diagnostic disable-next-line: param-type-mismatch
		return vim.tbl_map(function(xi) return type(xi) == "string" and { hl_group = xi } or xi end, x)
	end

	for _, part in ipairs(self.parts) do
		local start_col = #text
		text = text .. part[1]
		for _, mark in ipairs(to_extmarks(part[2] or {})) do
			table.insert(marks, {
				part.start_col or start_col,
				vim.tbl_extend("keep", mark, { end_col = part.end_col or #text }),
			})
		end
	end

	self.text = text
	self.marks = marks
end

return Line
