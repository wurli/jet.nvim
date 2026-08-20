local config = require("jet.core.config")
local utils = require("jet.core.utils")

---@class jet.Buf
---@field buf integer
---@field name string
---@field augroup integer
---@field ns integer
local Buf = {}
Buf.__index = Buf ---@private

function Buf:win()
	--
	return utils.buf_get_win(self.buf)
end

---@param focus? boolean
function Buf:open(focus)
	local win = self:win()

	if win then
		if focus then
			vim.api.nvim_set_current_win(win)
			vim.cmd.startinsert()
		end
	else
		local opts = vim.tbl_extend("keep", config.options.repl_win_opts or {}, {
			split = "right",
			style = "minimal",
			win = -1,
		})

		---@type integer
		win = vim.api.nvim_open_win(self.buf, false, opts)
		vim.api.nvim_win_set_hl_ns(win, self.ns)

		-- When the cursor is at the bottom of the REPL you get aut-scroll when
		-- new lines appear. This is a good state to start in.
		vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(self.buf), 0 })
	end

	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
end

function Buf:toggle()
	local win = self:win()
	if win then
		vim.api.nvim_win_close(win, true)
	else
		self:open()
	end
end

function Buf:delete()
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(self.buf) then
			pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
		end
	end)
end

---@param event vim.api.keyset.events | vim.api.keyset.events[]
---@param callback string | fun(args: vim.api.keyset.create_autocmd.callback_args): boolean?
function Buf:create_autocmd(event, callback)
	vim.api.nvim_create_autocmd(event, {
		buffer = self.buf,
		group = self.augroup,
		callback = callback,
	})
end

return Buf
