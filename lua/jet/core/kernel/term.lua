local config = require("jet.core.config")
local buf = require("jet.core.kernel.buf")

---@class jet.Kernel.Term : jet.Buf
---@field kernel jet.Kernel
---@field job_id integer
local Term = setmetatable({}, { __index = buf })
Term.__index = Term ---@private

---@class jet.Kernel.Term.init.Opts
---@field kernel jet.Kernel
---@field ns integer

---@param opts jet.Kernel.Term.init.Opts
---@return jet.Kernel.Term
function Term.init(opts)
	assert(opts.kernel.session_id, "Kernel session_id is required")

	local session_hash = opts.kernel.session_id:match("_([^_]+)$")
	local buf_name = opts.kernel.spec.display_name
	if session_hash then
		buf_name = buf_name .. " (" .. session_hash .. ")"
	end

	local out = buf.init(Term, {
		name = buf_name,
		ns = opts.ns,
		open_opts = {
			split = "right",
			win = -1,
			style = "minimal",
		},
	})

	out.kernel = opts.kernel
	vim.bo[out.buf].filetype = "jetrepl"

	--TODO: document this
	vim.b[out.buf].jet = { session_id = out.kernel.session_id }

	-- buf_call since the buf is not yet attached to a window.
	vim.api.nvim_buf_call(out.buf, function()
		out.job_id = vim.fn.jobstart({
			config.data.binary_path,
			"attach",
			out.kernel.session_id,
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
				out:delete()
			end,
		})
	end)

	-- It seems that jobstart() also sets the buf name, so this has to be done
	-- afterwards.
	vim.api.nvim_buf_set_name(out.buf, out.name)

	return out
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

return Term
