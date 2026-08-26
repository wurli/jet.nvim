local utils = require("jet.core.send.utils")

local M = {}

M.next_code = function()
	local pos = utils.next_expr_boundary({ direction = "down" })
	if pos then
		vim.fn.cursor(pos.row + 1, pos.col + 1)
	end
end

M.prev_code = function()
	local pos = utils.next_expr_boundary({ direction = "up" })
	if pos then
		vim.fn.cursor(pos.row + 1, pos.col + 1)
	end
end

---@return jet.send.Range?
M.get_next_expr = function()
	local code_pos = utils.next_expr_boundary({ current_ok = true })
	return require("jet.core.send.get_code").get_auto(code_pos)
end

--TODO: I think this API probably needs some polish. Doesn't feel particularly
--elegant to me. This function probs does too much:
-- * (optionally) gets code to send
-- * filters out comments and blank lines
-- * Finds a kernel
-- * Sends the code to the kernel
-- * (optionally) moves the cursor
---@param kernel jet.Kernel
---@param r jet.send.Range
---@param move_cursor boolean?
M.send_range = function(kernel, r, move_cursor)
	local code, ft = utils.range_code(r)

	if not code or (#code == 1 and code[1] == "") then
		return
	end

	if move_cursor == nil then
		move_cursor = vim.fn.mode():lower() ~= "v"
	end

	-- require("jet.core.manager").get({
	-- 	status = { "connected", "connecting" },
	-- 	filetype = ft,
	-- 	primary = true,
	-- }, function(k)
	kernel:send_repl(code, vim.filetype.get_option(ft, "tabstop") --[[@as integer]])

	if move_cursor then
		local expr_end = r.end_row
		local pos = utils.next_expr_boundary({}, {
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
	-- end)
end

---``` lua
---vim.keymap.set({ "n", "v" }, "<leader>js", require("jet.core.send").send_motion(), {
---    desc = "Execute code (Jet)",
---    expr = true,
---})
---```
M.send_motion = function()
	return require("jet.core.send.get_code").get_motion(function(rng)
		require("jet").get({
			filetype = true,
			primary = true,
			status = { "connected", "connecting" },
		}, function(k) M.send_range(k, rng, false) end)
	end)
end

return M
