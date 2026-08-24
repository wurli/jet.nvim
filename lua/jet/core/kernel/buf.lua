local utils = require("jet.core.utils")

---@class jet.Buf
---@field buf integer
---@field name string
---@field augroup integer
---@field ns integer
---@field kernel jet.Kernel
---@field open_opts vim.api.keyset.win_config | fun(): vim.api.keyset.win_config
local Buf = {}
Buf.__index = Buf ---@private

---@class jet.Buf.init.Opts
---@field name string
---@field ns integer
---@field kernel jet.Kernel
---@field open_opts vim.api.keyset.win_config | fun(): vim.api.keyset.win_config

---@generic T
---@param class? T
---@param opts jet.Buf.init.Opts
---@return T
function Buf.init(class, opts)
	local out = setmetatable({
		kernel = opts.kernel,
		ns = opts.ns,
		name = opts.name,
		open_opts = opts.open_opts,
		augroup = vim.api.nvim_create_augroup(opts.name, { clear = true }),
		buf = vim.api.nvim_create_buf(false, true),
	}, class or Buf)

	vim.b[out.buf].jet = { session_id = out.kernel.session_id }
	vim.api.nvim_buf_set_name(out.buf, out.name)

	return out
end

function Buf:win() return utils.buf_get_win(self.buf) end

---@param focus? boolean
---@param opts? vim.api.keyset.win_config
---@return integer # The opened window
function Buf:open(focus, opts)
	local win = self:win()

	if win then
		if focus then
			vim.api.nvim_set_current_win(win)
			if vim.bo[self.buf].buftype == "terminal" then
				vim.cmd.startinsert()
			end
		end
		return win
	end

	local open_opts = opts
		or type(self.open_opts) == "function" and self.open_opts()
		or type(self.open_opts) == "table" and self.open_opts
		or {}

	---@type integer
	win = vim.api.nvim_open_win(self.buf, false, open_opts)
	vim.api.nvim_win_set_hl_ns(win, self.ns)

	if vim.bo[self.buf].buftype == "terminal" then
		-- When the cursor is at the bottom of the REPL you get auto-scroll
		-- when new lines appear. This is a good state to start in.
		vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(self.buf), 0 })
	end

	vim.wo[win].number = false
	vim.wo[win].relativenumber = false

	return win
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
