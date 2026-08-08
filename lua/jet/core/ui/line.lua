---@alias jet.ui.line.parts { [1]: string, [2]?: string | vim.api.keyset.set_extmark }[]
---@alias jet.ui.line.extmark { [1]: integer, [2]: integer, [3]: vim.api.keyset.set_extmark }

---@class jet.ui.line
---@field indent integer
---@field timer? boolean
---@field on_refresh table<string, fun(self: jet.ui.line)> Called after `refresh` is called
---@field parts jet.ui.line.parts
---@field make_parts fun(): { [1]: string, [2]?: string }[] Reset `parts`
---@field text string
---@field lnum? integer
---@field marks jet.ui.line.extmark[]
---@field stopped boolean
---@field on_close? fun(self: jet.ui.line)
---@field data table<string, any>
local Line = {}
Line.__index = Line

---@param opts Partial<jet.ui.line>
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

	for _, part in ipairs(self.parts) do
		local start_col = #text
		text = text .. part[1]
		if part[2] then
			---@type vim.api.keyset.set_extmark
			local opts = { end_col = #text }

			if type(part[2]) == "string" then
				opts.hl_group = part[2]
			elseif type(part[2]) == "table" then
				opts = vim.tbl_extend("force", opts, part[2])
			end

			table.insert(marks, { self.lnum - 1, start_col, opts })
		end
	end

	self.text = text
	self.marks = marks
end

return Line
