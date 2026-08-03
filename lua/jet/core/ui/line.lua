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
---@field data table<string, any>
local Line = {}
Line.__index = Line

---@class jet.ui.line.new.opts
---@field indent? integer
---@field interval? integer
---@field make_parts fun(): jet.ui.line.parts Reset `parts`
---@field data? table<string, any>

---@param opts jet.ui.line.new.opts
Line.new = function(opts)
	local out = setmetatable({
		indent = (opts.indent or 0) * 2,
		interval = opts.interval,
		parts = {},
		make_parts = opts.make_parts,
		data = opts.data or {},
	}, Line)

	return out
end

function Line:refresh()
	self.parts = self.make_parts()
	self.text, self.marks = self:resolve()
	if self.on_refresh then
		self:on_refresh()
	end
end

function Line:watch()
	if not self.interval then
		return
	end
	self.timer = vim.uv.new_timer()
	if not self.timer then
		return
	end
	self.timer:start(self.interval, self.interval, function() self:refresh() end)
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
