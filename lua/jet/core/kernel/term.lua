local config = require("jet.core.config")
local utils = require("jet.core.utils")

---@class jet.Kernel.Term
---@field job_id integer
---@field buf integer
---@field buf_name string
---@field augroup integer
---@field ns integer
local Term = {}
Term.__index = Term ---@private

---@class jet.Kernel.Term.init.Opts
---@field session_id string
---@field display_name string
---@field ns integer

---@param opts jet.Kernel.Term.init.Opts
---@return jet.Kernel.Term
function Term.init(opts)
	local session_hash = (opts.session_id or ""):match("_([^_]+)$")
	local buf_name = opts.display_name
	if session_hash then
		buf_name = buf_name .. " (" .. session_hash .. ")"
	end

	local self = setmetatable({
		augroup = vim.api.nvim_create_augroup(buf_name, { clear = true }),
		ns = opts.ns,
	}, Term)

	local term_buf = vim.api.nvim_create_buf(false, true)

	--TODO: document this
	vim.b[term_buf].jet = { session_id = opts.session_id }

	-- buf_call since the buf is not yet attached to a window.
	vim.api.nvim_buf_call(term_buf, function()
		local term_job_id = vim.fn.jobstart({
			config.data.binary_path,
			"attach",
			opts.session_id,
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

function Term:win()
	--
	return utils.buf_get_win(self.buf)
end

---@return boolean
function Term:open()
	local win = self:win()
	local focus_gained = false

	if win then
		vim.api.nvim_set_current_win(win)
		vim.cmd.startinsert()
		focus_gained = true
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

	return focus_gained
end

function Term:toggle()
	local win = self:win()
	if win then
		vim.api.nvim_win_close(win, true)
	else
		self:open()
	end
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
