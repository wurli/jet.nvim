---@class jet.ui.linegroup
---@field make_lines? fun(): jet.ui.line[]
---@field lines jet.ui.line[]
---@field text string[]
---@field marks jet.ui.line.extmark[][]
local Linegroup = {}
Linegroup.__index = Linegroup

---@param lines jet.ui.line[] | fun(): jet.ui.line[]
Linegroup.new = function(lines)
	return setmetatable({
		make_lines = type(lines) == "function" and lines or nil,
		lines = type(lines) == "table" and lines or {},
		text = {},
		marks = {},
	}, Linegroup)
end

function Linegroup:refresh()
	if self.make_lines then
		self.lines = self.make_lines()
	end
	for _, l in ipairs(self.lines) do
		l:refresh()
	end
	self:resolve()
end

---@return boolean
function Linegroup:resolve()
	local text, marks = {}, {}
	for _, l in ipairs(self.lines) do
		l:resolve()
		table.insert(text, l.text)
		table.insert(marks, l.marks)
	end
	local len_changed = #text ~= #(self.text or {})
	self.text, self.marks = text, marks
	return len_changed
end

return Linegroup
