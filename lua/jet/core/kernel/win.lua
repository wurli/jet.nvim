---@class jet.Win
---@field private win integer
---@field ns integer
---If `true` then `Win:open()` will focus an already open window, otherwise
---it's a no-op.
---@field focus boolean
---@field kernel jet.Kernel
---@field open_opts? vim.api.keyset.win_config | fun(k: jet.Kernel): vim.api.keyset.win_config
local Win = {}
Win.__index = Win

---@param buf integer | jet.Buf
local to_bufnr = function(buf) return type(buf) == "number" and buf or buf.buf end

---@class jet.Win.init.Opts
---@field open_opts jet.Win["open_opts"]
---@field ns jet.Win["ns"]
---@field kernel jet.Win["kernel"]
---@field focus jet.Win["focus"]

---@param opts jet.Win.init.Opts
Win.init = function(opts)
	if opts.focus == nil then
		opts.focus = false
	end
	return setmetatable(vim.tbl_extend("force", opts, { win = -99 }), Win)
end

---@return string
function Win:name()
	for name, w in pairs(self.kernel.wins) do
		if w == self then
			return name
		end
	end
	error("Could not determine the window name")
end

---Opens with the following algorithm
---
---* If the window is not open, opens with `buf`
---* If the window is open with `buf`, focus the window (if `Win.focus`)
---* Otherwise, if the window is open with another buffer:
---  * Does the buffer have `vim.b.jet` set? If so, show `buf` in the window
---  * Otherwise, open a fresh window, resetting `self.win`.
---
---@param buf integer | jet.Buf
---@param opts vim.api.keyset.win_config?
---@param focus? boolean
---@return integer
function Win:open(buf, opts, focus)
	local curr_jet_buf = self:get_curr_jet_buf()

	if curr_jet_buf == buf then
		if focus or self.focus then
			vim.api.nvim_set_current_win(self.win)
			if vim.bo[buf].buftype == "terminal" then
				vim.cmd.startinsert()
			end
		end
		return self.win
	end

	local bufnr = to_bufnr(buf)

	if curr_jet_buf and vim.api.nvim_win_is_valid(self.win) then
		vim.api.nvim_win_set_buf(self.win, bufnr)
	else
		self.win = vim.api.nvim_open_win(bufnr, false, opts or self:make_open_opts())
	end

	vim.api.nvim_win_set_hl_ns(self.win, self.ns)

	if vim.bo[bufnr].buftype == "terminal" then
		-- When the cursor is at the bottom of the REPL you get auto-scroll
		-- when new lines appear. This is a good state to start in.
		vim.api.nvim_win_set_cursor(self.win, { vim.api.nvim_buf_line_count(bufnr), 0 })
	end

	return self.win
end

---@private
---@return vim.api.keyset.win_config
function Win:make_open_opts()
	if type(self.open_opts) == "function" then
		local out = self.open_opts(self.kernel)
		out.style = "minimal"
		return out
	elseif type(self.open_opts) == "table" then
		local out = self.open_opts
		out.style = "minimal"
		return out
	else
		return {
			style = "minimal",
			split = "right",
			win = -1,
		}
	end
end

---@param buf? jet.Buf | integer
function Win:close(buf)
	if self:get_curr_jet_buf(buf) and vim.api.nvim_win_is_valid(self.win) then
		vim.api.nvim_win_close(self.win, true)
	end
end

---@param buf integer | jet.Buf
function Win:toggle(buf)
	if self:get_curr_jet_buf(buf) then
		self:close(buf)
	else
		self:open(buf)
	end
end

---@param buf? integer | jet.Buf
---@return integer?
function Win:get_curr_jet_buf(buf)
	local curr_buf = self:get_buf()
	if buf and to_bufnr(buf) ~= curr_buf then
		return nil
	end
	for _, k_buf in pairs(self.kernel.bufs) do
		if k_buf.buf == curr_buf and k_buf.win_name == self:name() then
			return curr_buf
		end
	end
end

---@param buf? integer | jet.Buf
function Win:winnr(buf)
	if self:get_curr_jet_buf(buf) then
		return self.win
	end
end

---@return integer?
function Win:get_buf()
	if vim.api.nvim_win_is_valid(self.win) then
		return vim.api.nvim_win_get_buf(self.win)
	end
end

return Win
