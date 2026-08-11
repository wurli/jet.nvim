---@class jet.ui.linegroup
---@field make_lines fun(): jet.ui.line[]
---@field lines jet.ui.line[]
---@field text string[]
---@field marks jet.ui.line.extmark[][]
---@field on_refresh? fun(self: jet.ui.linegroup)
---@field timer? boolean
---@field stopped? boolean
local Linegroup = {}
Linegroup.__index = Linegroup

---@param opts Partial<jet.ui.linegroup>
---@param lines fun(): jet.ui.line | jet.ui.linegroup
Linegroup.new = function(opts, lines)
	return setmetatable({
		make_lines = lines,
		timer = opts.timer,
	}, Linegroup)
end

---@return boolean Whether the number of lines in the group has changed
function Linegroup:refresh()
	if self.stopped then
		return false
	end
	self.lines = self.make_lines()
	for _, l in ipairs(self.lines) do
		l:refresh()
	end
	local len_changed = self:resolve()
	if self.on_refresh then
		self:on_refresh()
	end
	return len_changed
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
