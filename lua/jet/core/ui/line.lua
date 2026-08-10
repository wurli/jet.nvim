---@alias jet.ui.line.parts { [1]: string, [2]?: string | string[] | vim.api.keyset.set_extmark | vim.api.keyset.set_extmark[], start_col?: integer, end_col?: integer }[]
---@alias jet.ui.line.extmark { [1]: integer, [2]: integer, [3]: vim.api.keyset.set_extmark }

---@class jet.ui.line
---@field indent integer
---@field timer? boolean
---@field on_refresh table<string, fun(self: jet.ui.line)> Called after `refresh` is called
---@field parts jet.ui.line.parts
---@field make_parts fun(): jet.ui.line.parts Reset `parts`
---@field text string
---@field lnum? integer
---@field marks jet.ui.line.extmark[]
---@field stopped boolean
---@field on_close? fun(self: jet.ui.line)
---@field data table<string, any>
local Line = {}
Line.__index = Line

---passing `Partial<jet.ui.line>` stops emmylua_ls enforcing return type of
---`make_parts()`, so just duplicate some types here.
---@class jet.ui.line.opts
---@field make_parts fun(): jet.ui.line.parts Reset `parts`
---@field indent? integer
---@field timer? boolean
---@field on_refresh? table<string, fun(self: jet.ui.line)> Called after `refresh` is called
---@field parts? jet.ui.line.parts
---@field lnum? integer
---@field on_close? fun(self: jet.ui.line)
---@field data? table<string, any>

---@param opts jet.ui.line.opts
Line.new = function(opts)
	return setmetatable({
		indent = (opts.indent or 0) * 2,
		timer = opts.timer,
		make_parts = opts.make_parts,
		on_close = opts.on_close,
		data = opts.data or {},
		on_refresh = opts.on_refresh or {},
		parts = {},
		stopped = false,
	}, Line)
end

---@param lnum? integer
function Line:refresh(lnum)
	if self.stopped then
		return
	end
	self.lnum = lnum or self.lnum
	self.parts = self.make_parts()
	self:resolve()
	for _, fn in pairs(self.on_refresh) do
		fn(self)
	end
end

function Line:resolve()
	assert(self.lnum, "Line:refresh must be called before Line:resolve")

	local text = string.rep(" ", self.indent)
	---@type jet.ui.line.extmark[]
	local marks = {}

	---@param x string | string[] | vim.api.keyset.set_extmark | vim.api.keyset.set_extmark[]
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
				self.lnum - 1,
				part.start_col or start_col,
				vim.tbl_extend("keep", mark, { end_col = part.end_col or #text }),
			})
		end
	end

	self.text = text
	self.marks = marks
end

return Line
