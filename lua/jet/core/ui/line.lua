---@alias jet.ui.line.parts { [1]: string, [2]?: string | vim.api.keyset.set_extmark }[]

---@class jet.ui.line
---@field timer? uv.uv_timer_t
---@field indent integer
---@field interval? integer
---@field on_refresh? fun(self: jet.ui.line) Called after `refresh` is called
---@field parts jet.ui.line.parts
---@field make_parts fun(): jet.ui.line.parts Reset `parts`
---@field text string
---@field marks vim.api.keyset.set_extmark[]
---@field alias? string For debugging
---@field on_unwatch? fun(self: jet.ui.line)
---@field data table<string, any>
local Line = {}
Line.__index = Line

---@class jet.ui.line.new.opts
---@field indent? integer
---@field interval? integer
---@field make_parts fun(): jet.ui.line.parts Reset `parts`
---@field data? table<string, any>
---@field on_unwatch? fun(self: jet.ui.line)
---@field alias? string For debugging

local id = 0

---@param opts jet.ui.line.new.opts
Line.new = function(opts)
	if opts.interval and not opts.alias then
		error("jet.ui.line.new: interval requires alias")
	end

	local out = setmetatable({
		indent = (opts.indent or 0) * 2,
		interval = opts.interval,
		parts = {},
		make_parts = opts.make_parts,
		alias = opts.alias and (id .. " " .. opts.alias .. " (every " .. opts.interval .. "ms)") or nil,
		on_unwatch = opts.on_unwatch,
		data = opts.data or {},
	}, Line)

	if opts.alias then
		id = id + 1
	end

	return out
end

function Line:refresh()
	self.parts = self.make_parts()
	self.text, self.marks = self:resolve()
	if self.on_refresh then
		self:on_refresh()
	end
end

-- for debugging
Line.open_timers = {}

function Line:watch()
	if not self.interval then
		return
	end
	self.timer = vim.uv.new_timer()
	if not self.timer then
		return
	end
	if self.alias then
		Line.open_timers[self.alias] = self.timer
	end
	self.timer:start(self.interval, self.interval, function() self:refresh() end)
end

function Line:unwatch()
	if self.timer then
		self.timer:stop()
		self.timer:close(function()
			self.timer = nil
			if self.alias then
				Line.open_timers[self.alias] = nil
			end
		end)
	end
	if self.on_unwatch then
		self:on_unwatch()
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
