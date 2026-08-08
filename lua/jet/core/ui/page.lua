---@class jet.ui.page
---@field buf integer
---@field ns integer
---@field lines jet.ui.line<any>[]
---@field text string[]
---@field get_lines fun(callback: fun(lines: jet.ui.line<any>[]))
---@field on_refresh? fun(self: jet.ui.page)
---@field timer uv.uv_timer_t
local Page = {}
Page.__index = Page

---@class jet.ui.page.new.opts
---@field get_lines fun(callback: fun(lines: jet.ui.line<any>[]))
---@field on_refresh? fun(self: jet.ui.page)
---@field buf integer
---@field ns integer

---@param opts jet.ui.page.new.opts
---nreturn jet.ui.page
Page.new = function(opts)
	local out = setmetatable(opts, Page)
	out.lines = {}

	vim.bo[out.buf].buftype = "nofile"
	vim.bo[out.buf].modifiable = false

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
	self.timer:start(100, 100, function()
		for _, l in ipairs(self.lines) do
			if l.timer then
				l:refresh()
			end
		end
	end)
end

function Page:close()
	for _, l in ipairs(self.lines) do
		if l.on_close then
			l:on_close()
		end
	end

	vim.schedule(function()
		self.timer:stop()
		self.timer:close()
		if vim.api.nvim_buf_is_valid(self.buf) then
			vim.api.nvim_buf_delete(self.buf, { force = true })
		end
	end)
end

---@param callback fun()
function Page:update_lines(callback)
	self.get_lines(function(lines)
		self.lines = lines
		callback()
	end)
end

function Page:refresh()
	for _, l in ipairs(self.lines) do
		l.stopped = true
	end

	self:update_lines(function()
		local text = {} ---@type string[]
		local extmarks = {} ---@type { [1]: integer, [2]: vim.api.keyset.set_extmark }[][]

		for lnum, l in ipairs(self.lines) do
			l:refresh(lnum)
			table.insert(text, l.text)
			table.insert(extmarks, l.marks)

			-- When a 'line' updates, set the buffer text/marks for that line
			l.on_refresh.update_page = function(line)
				vim.schedule(function()
					self:set_line(lnum, line.text)
					self:clear_marks(lnum - 1, lnum)
					self:set_marks(line.marks)
				end)
			end
		end

		self.text = text

		if not vim.api.nvim_buf_is_valid(self.buf) then
			return
		end

		self:set_lines()

		self:clear_marks()
		for _, marks in ipairs(extmarks) do
			self:set_marks(marks)
		end

		if self.on_refresh then
			self:on_refresh()
		end
	end)
end

function Page:set_line(lnum, text) self:set_lines({ text }, lnum - 1, lnum) end

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
