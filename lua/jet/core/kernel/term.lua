local config = require("jet.core.config")

---@class jet.Kernel.Term
---@field job_id integer
---@field buf integer
---@field buf_name string
---@field augroup integer
local Term = {}
Term.__index = Term ---@private

---@param session_id string
---@param display_name string
---@return jet.Kernel.Term
function Term.init(session_id, display_name)
	local session_hash = (session_id or ""):match("_([^_]+)$")
	local buf_name = display_name
	if session_hash then
		buf_name = buf_name .. " (" .. session_hash .. ")"
	end

	local self = setmetatable({
		augroup = vim.api.nvim_create_augroup(buf_name, { clear = true }),
	}, Term)

	local term_buf = vim.api.nvim_create_buf(false, true)

	--TODO: document this
	vim.b[term_buf].jet = { session_id = session_id }

	-- buf_call since the buf is not yet attached to a window.
	vim.api.nvim_buf_call(term_buf, function()
		local term_job_id = vim.fn.jobstart({
			config.data.binary_path,
			"attach",
			session_id,
			"--banner",
			"--session-name",
			"nvim",
			"--no-graphics",
			config.options.send.send_by_expr and "--no-indent" or nil,
		}, {
			term = true,
			on_exit = function()
				-- TODO: perhaps we don't want this - e.g. a kernel crashes
				-- and suddenly all the info from the console is gone. For
				-- now it's convenient, but maybe review in future or add
				-- config.
				self:delete()
			end,
		})

		-- It seems that jobstart() also sets the buf name, so this has to be
		-- done afterwards.
		vim.api.nvim_buf_set_name(term_buf, buf_name)

		self.job_id = term_job_id
		self.buf = term_buf
		self.buf_name = buf_name
	end)

	return self
end

function Term:delete()
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(self.buf) then
			pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
		end
	end)
end

---@param event vim.api.keyset.events | vim.api.keyset.events[]
---@param callback string | fun(args: vim.api.keyset.create_autocmd.callback_args): boolean?
function Term:create_autocmd(event, callback)
	vim.api.nvim_create_autocmd(event, {
		buffer = self.buf,
		group = self.augroup,
		callback = callback,
	})
end

return Term
