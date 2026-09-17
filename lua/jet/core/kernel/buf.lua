---@class jet.Buf
---@field buf integer
---@field layout_pos integer
---@field name string
---@field augroup integer
---@field ns integer
---@field kernel jet.Kernel
local Buf = {}
Buf.__index = Buf ---@private

---@class jet.Buf.init.Opts
---@field name string
---@field ns integer
---@field kernel jet.Kernel
---@field layout_pos integer

---@generic T
---@param class? T
---@param opts jet.Buf.init.Opts
---@return T
function Buf.init(class, opts)
	local out = setmetatable({
		kernel = opts.kernel,
		ns = opts.ns,
		name = opts.name,
		layout_pos = opts.layout_pos,
		augroup = vim.api.nvim_create_augroup(opts.name, { clear = true }),
		buf = vim.api.nvim_create_buf(false, true),
	}, class or Buf)

	vim.b[out.buf].jet = {
		session_id = out.kernel.session_id,
		layout_pos = out.layout_pos,
	}
	vim.api.nvim_buf_set_name(out.buf, out.name)

	return out
end

---Get a window displaying the buffer, if there is one
---@return jet.Win
function Buf:win()
	local w = self.kernel.windows[self.layout_pos]
	assert(w, "Kernel window %d not found. Kernel has %d registered windows", self.layout_pos, #self.kernel.windows)
	return w
end

---@param opts vim.api.keyset.win_config?
---@param focus? boolean
---@return integer # The opened window
function Buf:open(opts, focus) return self:win():open(self.buf, opts, focus) end

function Buf:toggle() self:win():toggle(self) end

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
