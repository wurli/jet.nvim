local M = {}
local api = require("jet.core.api")
local utils = require("jet.core.utils")
local line = require("jet.core.ui.line")
local page = require("jet.core.ui.page")

---@param data jet.kernel
---@param indent integer?
local active_kernel_line = function(data, indent)
	assert(data.session_id, "Kernel must have a session_id")
	local out = line.new(data, indent, 200)

	function out:refresh()
		local status, status_icon = self.data:status()
		assert(self.data.session_info, "Kernel must have session info")
		self.parts = {
			{ status_icon .. "  ", status == "external" and "@variable.builtin" or "@string.regexp" },
			{ "(" .. utils.time_since(self.data.session_info.created_at) .. ") ", "Comment" },
			{ self.data.session_id .. " " },
		}
	end

	return out
end

---@param name string
---@param indent integer?
local kernel_group_line = function(name, indent)
	local out = line.new(nil, indent)
	out.parts = { { name, "JetH2" } }
	return out
end

---@param data jet.ui.kernel_group
---@param indent integer?
local kernel_info_line = function(data, indent)
	local out = line.new(data, indent)
	out.parts = { { out.data.kernel.spec.display_name } }
	table.insert(out.parts, { "    " })
	table.insert(out.parts, { utils.path_shorten(out.data.kernel.spec_path), "Directory" })
	return out
end

---@param indent integer?
local header_line = function(indent)
	local out = line.new(nil, indent)
	out.parts = { { "Jet ", "Title" }, { " ", "OkMsg" } }
	return out
end

---@param indent integer?
local url_line = function(indent)
	local out = line.new(nil, indent)
	out.parts = { { "https://github.com/wurli/jet", "JetUrl" } }
	return out
end

---@param indent integer?
local keymaps_line = function(indent)
	local out = line.new(nil, indent)
	out.parts = {
		{ " Open (<cr>) ", "JetButton" },
		{ "  " },
		{ " New session (n) ", "JetButton" },
		{ "  " },
		{ " Shut down (x) ", "JetButton" },
		{ "  " },
		{ " Quit (q) ", "JetButton" },
	}
	return out
end

local blank_line = function()
	local out = line.new(nil, 0)
	out.parts = { { "" } }
	return out
end

---@class jet.ui.kernel_group
---@field kernel jet.kernel
---@field external jet.kernel[]
---@field connected jet.kernel[]

---@return jet.ui.kernel_group[]
local list_kernel_groups = function()
	local kernel_list = api.list_kernels({}, {})

	---@type table<string, { kernel: jet.kernel, external: jet.kernel[], connected: jet.kernel[] }>
	local kernels_grouped = {}
	for _, k in ipairs(kernel_list) do
		local path = utils.path_normalise(k.spec_path)
		if not kernels_grouped[path] then
			kernels_grouped[path] = {
				kernel = k, -- Doesn't matter which kernel this one is, since we only use its basic info (name, path, etc.)
				external = {},
				connected = {},
			}
		end
	end

	for _, k in ipairs(api.filter_kernels(kernel_list, { status = { "connected", "connecting" } })) do
		table.insert(kernels_grouped[utils.path_normalise(k.spec_path)].connected, k)
	end

	for _, k in ipairs(api.filter_kernels(kernel_list, { status = { "external" } })) do
		table.insert(kernels_grouped[utils.path_normalise(k.spec_path)].external, k)
	end

	-- Makes sorting possible
	local out = vim.tbl_values(kernels_grouped)

	table.sort(out, function(a, b)
		---@type table<jet.kernel.status, integer>
		local status_ranks = {
			connected = 1,
			connecting = 1,
			external = 2,
			inactive = 3,
		}

		local a_min_status = status_ranks[(a.connected[1] or a.external[1] or a.kernel):status()]
		local b_min_status = status_ranks[(b.connected[1] or b.external[1] or b.kernel):status()]

		if a_min_status ~= b_min_status then
			return a_min_status < b_min_status
		end

		return a.kernel.spec.display_name < b.kernel.spec.display_name
	end)

	for _, running in pairs(out) do
		table.sort(running.connected, function(a, b) return a.session_id < b.session_id end)
		table.sort(running.external, function(a, b) return a.session_id < b.session_id end)
	end

	return out
end

---@return jet.ui.line<jet.kernel>[]
local kernel_lines = function()
	local groups = list_kernel_groups()
	local lines = {}

	local group_name = ""

	for _, group in ipairs(groups) do
		local last_group = group_name
		group_name = (#group.connected > 0 or #group.external > 0) and "Active Kernels" or "Inactive Kernels"
		if group_name ~= last_group then
			table.insert(lines, kernel_group_line(group_name))
		end

		table.insert(lines, kernel_info_line(group, 2))
		local any_connected = false
		for _, k in ipairs(group.connected) do
			table.insert(lines, active_kernel_line(k, 2))
			any_connected = true
		end
		for _, k in ipairs(group.external) do
			table.insert(lines, active_kernel_line(k, 2))
			any_connected = true
		end
		if any_connected then
			table.insert(lines, blank_line())
		end
	end
	return lines
end

-- 1. Global refresh (sets all lines)
-- 2. Line refresh (sets only one line)
--  - Triggered by the ui or the line object itself
--	- Needs the current line no - or could take a callback?

M.show = function()
	require("jet.core.ui.colours").setup()

	local ui = page.new({
		buf = vim.api.nvim_create_buf(false, true),
		ns = vim.api.nvim_create_namespace("jet.ui"),
		get_lines = function()
			local lines = {
				header_line(),
				url_line(),
				blank_line(),
				keymaps_line(),
				blank_line(),
			}
			for _, l in ipairs(kernel_lines()) do
				table.insert(lines, l)
			end
			return lines
		end,
		-- Our abstractions only allow setting one layer of highlights, so just
		-- set additional highlights in a second pass by pattern matching.
		on_refresh = function(self)
			for match_start, match_end in utils.gfind(self.text[4], "%(.-%)") do
				vim.api.nvim_buf_set_extmark(self.buf, self.ns, 3, match_start - 1, {
					end_col = match_end,
					hl_group = "JetSpecial",
				})
			end
		end,
	})

	vim.keymap.set("n", "q", function() vim.api.nvim_win_close(0, true) end)

	local screen_width = vim.o.columns
	local screen_height = vim.o.lines
	local scale = function(x, y) return math.floor(x * y) end
	vim.api.nvim_open_win(ui.buf, true, {
		relative = "editor",
		width = scale(screen_width, 0.8),
		height = scale(screen_height, 0.8),
		row = scale(screen_height, 0.2 / 2),
		col = scale(screen_width, 0.2 / 2),
		style = "minimal",
		border = "rounded",
	})
end

return M
