---@class jet.ui.page
---@field buf integer
---@field ns integer
---@field groups jet.ui.linegroup[]
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

	out:refresh()
	out:start_timer()

	return out
end

function Page:start_timer()
	local timer, err = vim.uv.new_timer()
	if not timer then
		error("Failed to create timer: " .. (err or "unknown error"))
	end
	self.timer = timer
	self.timer:start(self.interval, self.interval, function() self:refresh_incremental() end)
end

function Page:refresh_incremental()
	local len_changed = false
	for _, g in ipairs(self.groups) do
		if g.timer then
			len_changed = len_changed or g:refresh()
		end
	end
	self:resolve()
end

function Page:resolve()
	local text = {}
	local marks = {}
	for _, g in ipairs(self.groups) do
		for _, line in ipairs(g.text) do
			table.insert(text, line)
		end
		for _, line_marks in ipairs(g.marks) do
			-- TODO: update marks to record the correct line numbers
			table.insert(marks, line_marks)
		end
	end
	self.text = text
	self.marks = marks
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

---@param callback fun()
function Page:update_groups(callback)
	self.get_groups(function(groups)
		self.groups = groups
		callback()
	end)
end

function Page:refresh()
	for _, g in ipairs(self.groups) do
		g.stopped = true
	end

	self:update_groups(function()
		self:resolve()
		self:set_lines()
		self:clear_marks()
		self:set_marks(self.marks)
	end)
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

function Page:set_marks(marks)
	if vim.api.nvim_buf_is_valid(self.buf) then
		for _, mark in ipairs(marks) do
			vim.api.nvim_buf_set_extmark(self.buf, self.ns, mark[1], mark[2], mark[3])
		end
	end
end

return Page
