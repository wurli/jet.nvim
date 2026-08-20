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

---@param focus? boolean
function Term:open(focus)
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

---@param code string | string[] Code to be sent
---@param tabstop? integer Optional; number of spaces to use for tab characters
---@param on_send? fun(code: string[]) Optional; callback to be called after code is sent
function Term:send(code, tabstop, on_send)
	tabstop = tabstop or vim.bo.tabstop or 4
	if type(code) == "string" then
		code = vim.split(code, "[\n\r]", { plain = false })
	end

	-- Remove trailing empty lines
	for i = #code, 1, -1 do
		if code[i] == "" then
			table.remove(code, i)
		else
			break
		end
	end

	-- Wrap in a bracketed-paste sequence so the REPL on the other end
	-- accumulates the whole block as one cell instead of evaluating each
	-- line separately, then submit with a single CR (Enter, in raw mode).
	-- This is exactly what a terminal emits on Cmd/Ctrl+V — works with
	-- any REPL that honors bracketed paste.
	---@diagnostic disable-next-line: param-type-mismatch
	for i, line in ipairs(code) do
		code[i] = line:gsub("\t", string.rep(" ", tabstop))
	end

	-- Allow the user to modify the code before we send it. This is
	-- particularly helpful, e.g. for ipython, which requires an extra newline
	-- at the end of statements which end on an indented line in order to be
	-- actually sent to the kernel (otherwise you get the continuation prompt
	-- '+ ...').
	if on_send then
		on_send(code)
	end

	code = table.concat(code, "\r")

	-- We use bracketed paste so the Jet REPL knows not to evaluate the code
	-- until the end of the paste. This matches behaviour of Positron.
	if not config.options.send.send_by_expr then
		-- https://en.wikipedia.org/wiki/Bracketed-paste#Description_of_bracketed-paste
		local bracketed_paste_start = "\x1b[200~"
		local bracketed_paste_end = "\x1b[201~"
		code = bracketed_paste_start .. code .. bracketed_paste_end
	end

	vim.fn.chansend(self.job_id, code .. "\r")
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
