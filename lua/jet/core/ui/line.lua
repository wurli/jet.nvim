---@generic T
---@class jet.ui.line<T>
---@field data T
---@field timer? uv.uv_timer_t
---@field indent integer
---@field interval? integer
---@field refresh? fun(self: jet.ui.line<T>) Reset `parts`
---@field parts { [1]: string, [2]?: string | vim.api.keyset.set_extmark }[]
local Line = {}
Line.__index = Line

---@generic T
---@param data T
---@param indent? integer
---@param interval? integer
---@return jet.ui.line<T>
Line.new = function(data, indent, interval)
	return setmetatable({
		data = data,
		indent = (indent or 1) * 2,
		interval = interval,
		parts = {},
	}, Line)
end

---@param callback fun(text: string, marks: { [1]: integer, [2]: vim.api.keyset.set_extmark }[])
function Line:watch(callback)
	if not (self.interval and self.refresh) then
		return
	end
	self.timer = vim.uv.new_timer()
	if not self.timer then
		return
	end
	self.timer:start(self.interval, self.interval, function()
		---@diagnostic disable-next-line: param-type-mismatch
		self:refresh()
		callback(self:resolve())
	end)
end

function Line:unwatch()
	if self.timer then
		self.timer:stop()
		self.timer:close()
		self.timer = nil
	end
end

---@return string, { [1]: integer, [2]: vim.api.keyset.set_extmark }[]
function Line:resolve()
	local text = string.rep(" ", self.indent)
	---@type { [1]: integer, [2]: vim.api.keyset.set_extmark }[]
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

			table.insert(marks, { start_col, opts })
		end
	end

	return text, marks
end

return Line
