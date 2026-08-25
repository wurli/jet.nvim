local utils = require("jet.core.send.utils")

local M = {}

M.send_chunk = function()
	--
end

--TODO: I think this API probably needs some polish. Doesn't feel particularly
--elegant to me. This function probs does too much:
-- * (optionally) gets code to send
-- * filters out comments and blank lines
-- * Finds a kernel
-- * Sends the code to the kernel
-- * (optionally) moves the cursor
---@param r jet.send.Range?
---@param move_cursor boolean?
M.send_auto = function(r, move_cursor)
	if move_cursor == nil then
		move_cursor = vim.fn.mode():lower() ~= "v"
	end

	local code_pos = utils.next_significant_pos({ accept_current = true })
	r = r or require("jet.core.send.get_code").get_auto(code_pos)

	if not r then
		return
	end

	local code, ft = utils.range_code(r)

	if not code or (#code == 1 and code[1] == "") then
		return
	end

	table.insert(code, "")

	require("jet.core.manager").get({
		status = { "connected", "connecting" },
		filetype = ft,
		primary = true,
	}, function(k)
		k:send_repl(code, vim.filetype.get_option(ft, "tabstop") --[[@as integer]])

		if move_cursor then
			local expr_end = r.end_row
			local pos = utils.next_significant_pos({}, {
				buf = r.buf,
				row = expr_end,
				col = 0,
			})
			local line = pos and pos.row or (expr_end + 1)
			vim.schedule(function() vim.fn.cursor(line + 1, 0) end)
		end

		if vim.fn.mode():lower() == "v" then
			local esc_termcode = "\27"
			vim.api.nvim_feedkeys(esc_termcode, "n", false)
		end
	end)
end

M.send_motion = function()
	return require("jet.core.send.get_code").get_motion(function(rng) M.send_auto(rng, false) end)
end

return M
