---@class jet.ui.page
---@field buf integer
---@field ns integer
---@field groups jet.ui.linegroup[]
---@field lines jet.ui.line[]
---@field text string[]
---@field marks jet.ui.line.extmark[]
---@field get_groups fun(callback: fun(groups: jet.ui.linegroup[]))
---@field timer uv.uv_timer_t
---@field interval integer
local Page = {}
Page.__index = Page

---@class jet.ui.page.new.opts
---@field get_groups fun(callback: fun(groups: jet.ui.linegroup[]))
---@field ns integer

---@param opts jet.ui.page.new.opts
---@return jet.ui.page
Page.new = function(opts)
	local out = setmetatable(opts, Page)
	out.buf = vim.api.nvim_create_buf(false, true)
	out.groups = {}
	out.interval = 100
	out.lines = {}
	out.groups = {}
	out.text = {}

	out:refresh()
	out:start_timer()

	return out
end

function Page:close()
	vim.schedule(function()
		self.timer:stop()
		self.timer:close()
		if vim.api.nvim_buf_is_valid(self.buf) then
			vim.api.nvim_buf_delete(self.buf, { force = true })
		end
	end)
end

function Page:start_timer()
	local timer, err = vim.uv.new_timer()
	if not timer then
		error("Failed to create timer: " .. (err or "unknown error"))
	end
	self.timer = timer
	self.timer:start(self.interval, self.interval, function()
		vim.schedule(function() self:redraw() end)
	end)
end

function Page:refresh()
	for _, group in ipairs(self.groups) do
		group.stopped = true
	end
	self.get_groups(function(groups)
		self.groups = groups
		self:redraw()
	end)
end

function Page:redraw()
	for _, group in ipairs(self.groups) do
		group:refresh()
	end
	self:resolve()
	self:set_lines()
	self:clear_marks()
	self:set_marks(self.marks)
end

function Page:resolve()
	local lines = {} ---@type jet.ui.line[]
	local text = {} ---@type string[]
	local marks = {} ---@type jet.ui.line.extmark[]
	local lnum = 0
	for _, g in ipairs(self.groups) do
		for _, line in ipairs(g.lines) do
			table.insert(lines, line)
		end
		for _, line_text in ipairs(g.text) do
			table.insert(text, line_text)
		end
		for _, line_marks in ipairs(g.marks) do
			for _, mark in ipairs(line_marks) do
				local m = vim.deepcopy(mark)
				m.start_row = m.start_row and (m.start_row + lnum) or lnum
				m.mark.end_row = m.mark.end_row and (m.mark.end_row + lnum) or nil
				table.insert(marks, m)
			end
			lnum = lnum + 1
		end
	end
	self.lines = lines
	self.text = text
	self.marks = marks
end

function Page:set_lines(lines, start_lnum, end_lnum)
	if vim.api.nvim_buf_is_valid(self.buf) then
		vim.bo[self.buf].modifiable = true
		vim.api.nvim_buf_set_lines(self.buf, start_lnum or 0, end_lnum or -1, false, lines or self.text)
		vim.bo[self.buf].modifiable = false
	end
end

function Page:clear_marks(line_start, line_end)
	if vim.api.nvim_buf_is_valid(self.buf) then
		vim.api.nvim_buf_clear_namespace(self.buf, self.ns, (line_start or 1), line_end or -1)
	end
end

---@param marks jet.ui.line.extmark[]
function Page:set_marks(marks)
	if vim.api.nvim_buf_is_valid(self.buf) then
		for _, mark in ipairs(marks) do
			assert(mark.start_row and mark.start_col, "Mark must have start_row and start_col: " .. vim.inspect(mark))
			vim.api.nvim_buf_set_extmark(self.buf, self.ns, mark.start_row, mark.start_col, mark.mark)
		end
	end
end

return Page
