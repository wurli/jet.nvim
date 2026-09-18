---@class jet.Buf
---@field buf integer
---@field win_name string
---@field name string
---@field augroup integer
---@field ns integer
---@field kernel jet.Kernel
local Buf = {}
Buf.__index = Buf ---@private

---@class jet.Buf.init.Opts
---@field name string
---@field win_name string | keyof jet.Kernel.Windows
---@field kernel jet.Kernel

---@generic T
---@param class? T
---@param opts jet.Buf.init.Opts
---@return T
function Buf.init(class, opts)
	local out = setmetatable({
		kernel = opts.kernel,
		ns = vim.api.nvim_create_namespace("jet_highlights"),
		name = opts.name,
		win_name = opts.win_name,
		augroup = vim.api.nvim_create_augroup(opts.name, { clear = true }),
		buf = vim.api.nvim_create_buf(false, true),
	}, class or Buf)

	vim.b[out.buf].jet = { session_id = out.kernel.session_id }
	vim.api.nvim_buf_set_name(out.buf, out.name)

	return out
end

---Get the kernel window associated with the buffer
---@return jet.Win
function Buf:win()
	local out = self.kernel.wins[self.win_name]
	assert(
		out,
		string.format(
			"Kernel window '%s' not found. Kernel has windows %s",
			self.win_name,
			vim.inspect(vim.tbl_keys(self.kernel.wins))
		)
	)
	return out
end

---@param opts vim.api.keyset.win_config?
---@param focus? boolean
---@return integer # The opened window
function Buf:open(opts, focus) return self:win():open(self.buf, opts, focus) end

function Buf:toggle() self:win():toggle(self.buf) end

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
