---@class jet.ui.page
---@field buf integer
---@field ns integer
---@field lines jet.ui.line<any>[]
---@field text string[]
---@field get_lines fun(callback: fun(lines: jet.ui.line<any>[]))
---@field on_refresh? fun(self: jet.ui.page)
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
	return out
end

function Page:close()
	for _, l in ipairs(self.lines) do
		l:unwatch()
	end
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(self.buf) then
			vim.api.nvim_buf_delete(self.buf, { force = true })
		end
	end)
end

---@param callback fun()
function Page:update_lines(callback)
	for _, l in ipairs(self.lines) do
		l:unwatch()
	end
	self.get_lines(function(lines)
		self.lines = lines
		callback()
	end)
end

function Page:refresh()
	self:update_lines(function()
		local text = {} ---@type string[]
		local extmarks = {} ---@type { [1]: integer, [2]: vim.api.keyset.set_extmark }[][]

		for lnum, l in ipairs(self.lines) do
			l:refresh()
			table.insert(text, l.text)
			table.insert(extmarks, l.marks)

			l.on_refresh = function(line)
				vim.schedule(function()
					self:set_line(lnum, line.text)
					self:clear_marks(lnum - 1, lnum)
					self:set_marks(lnum, line.marks)
				end)
			end
		end

		self.text = text
		self:set_lines(text)

		self:clear_marks()
		for lnum, marks in ipairs(extmarks) do
			self:set_marks(lnum, marks)
		end

		if self.on_refresh then
			self:on_refresh()
		end

		self:watch_lines()
	end)
end

function Page:watch_lines()
	for _, l in ipairs(self.lines) do
		l:watch()
	end
end

function Page:set_line(lnum, text) self:set_lines({ text }, lnum - 1, lnum) end

function Page:set_lines(lines, start_lnum, end_lnum)
	if vim.api.nvim_buf_is_valid(self.buf) then
		vim.bo[self.buf].modifiable = true
		vim.api.nvim_buf_set_lines(self.buf, start_lnum or 0, end_lnum or -1, false, lines)
		vim.bo[self.buf].modifiable = false
	end
end

function Page:clear_marks(line_start, line_end)
	if vim.api.nvim_buf_is_valid(self.buf) then
		vim.api.nvim_buf_clear_namespace(self.buf, self.ns, (line_start or 1), line_end or -1)
	end
end

function Page:set_marks(lnum, marks)
	if vim.api.nvim_buf_is_valid(self.buf) then
		for _, mark in ipairs(marks) do
			vim.api.nvim_buf_set_extmark(self.buf, self.ns, lnum - 1, mark[1], mark[2])
		end
	end
end

return Page
