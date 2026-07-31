local M = {}
local api = require("jet.core.api")
local utils = require("jet.core.utils")

-- jet ui mockup
--
-- +--------------------------------------------------------------+
-- |                           Jet                                |
-- |                                                              |
-- | (<Enter>) Open (auto)  (n) New session  (x) Shut down        |
-- |                                                              |
-- | Ark R Kernel                                   (kernelspec)  |
-- |   session 1 (nvim)                            (session_id)  |
-- |   session 2 (nvim)                            (session_id)  |
-- | 󰺕  session 3 (external)                        (session_id)  |
-- |                                                              |
-- | Ipython                                        (kernelspec)  |
-- |   session 1 (nvim)                            (session_id)  |
-- |                                                              |
-- | Rust                                           (kernelspec)  |
-- | <no running sesssion>                                        |
-- |                                                              |
-- +--------------------------------------------------------------+

local ns = vim.api.nvim_create_namespace("jet.ui")

---@generic T
---@class jet.ui.line<T>
---@field data T
---@field timer? uv.uv_timer_t
---@field indent integer
---@field interval? integer
---@field parts { [1]: string, [2]?: string | vim.api.keyset.set_extmark }[]
local line = {}
line.__index = line

function line.refresh()
	-- Default implementation does nothing
end

---@param callback fun(text: string, marks: { [1]: integer, [2]: vim.api.keyset.set_extmark }[])
function line:watch(callback)
	if not self.interval then
		return
	end
	self.timer = vim.uv.new_timer()
	if not self.timer then
		return
	end
	self.timer:start(self.interval, self.interval, function()
		self:refresh()
		callback(self:resolve())
	end)
end

function line:resolve()
	local text = string.rep(" ", self.indent)
	---@type { [1]: integer, [2]: vim.api.keyset.set_extmark }[]
	local marks = {}

	for _, part in ipairs(self.parts) do
		local start_col = #text
		text = text .. part[1]
		if part[2] then
			---@type vim.api.keyset.set_extmark
			local opts = { end_col = #text }

			if type(part[2]) == "string" then
				opts.hl_group = part[2]
			elseif type(part[2]) == "table" then
				opts = vim.tbl_extend("force", opts, part[2])
			end

			table.insert(marks, { start_col, opts })
		end
	end

	return text, marks
end

---@generic T
---@param data T
---@param indent? integer
---@param interval? integer
---@return jet.ui.line<T>
local function new_line(data, indent, interval)
	return setmetatable({
		data = data,
		indent = (indent or 1) * 2,
		interval = interval,
	}, line)
end

---@param data jet.kernel
---@param indent integer?
local active_kernel_line = function(data, indent)
	assert(data.session_id, "Kernel must have a session_id")
	local out = new_line(data, indent, 200)

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
	local out = new_line(nil, indent)
	out.parts = { { name, "JetH2" } }
	return out
end

---@param data jet.ui.kernel_group
---@param indent integer?
local kernel_info_line = function(data, indent)
	local out = new_line(data, indent)
	out.parts = { { out.data.kernel.spec.display_name } }
	table.insert(out.parts, { "    " })
	table.insert(out.parts, { utils.path_shorten(out.data.kernel.spec_path), "Directory" })
	return out
end

---@param indent integer?
local header_line = function(indent)
	local out = new_line(nil, indent)
	out.parts = { { "Jet ", "Title" }, { " ", "OkMsg" } }
	return out
end

---@param indent integer?
local url_line = function(indent)
	local out = new_line(nil, indent)
	out.parts = { { "https://github.com/wurli/jet", "JetUrl" } }
	return out
end

---@param indent integer?
local keymaps_line = function(indent)
	local out = new_line(nil, indent)
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
	local out = new_line(nil, 0)
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

---``` lua
---for s, e in gfind("Hello, world!", "He(ll)o") do
---  vim.print({ s, e }) -- prints 5 5 and then 8 8
---end
---```
local gfind = function(string, pattern)
	local start = 1
	---@return integer?, integer?
	return function()
		local s, e = string:find(pattern, start)
		if s then
			start = e + 1
			return s, e
		end
	end
end

-- 1. Global refresh (sets all lines)
-- 2. Line refresh (sets only one line)
--  - Triggered by the ui or the line object itself
--	- Needs the current line no - or could take a callback?

M.show = function()
	require("jet.core.ui.colours").setup()
	local buf = vim.api.nvim_create_buf(false, true)

	----------------------------------------------
	--               Write lines                --
	----------------------------------------------
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

	local text = {} ---@type string[]
	local extmarks = {} ---@type { [1]: integer, [2]: vim.api.keyset.set_extmark }[][]
	for _, l in ipairs(lines) do
		l:refresh()
		local line_text, line_extmarks = l:resolve()
		table.insert(text, line_text)
		table.insert(extmarks, line_extmarks)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
	for lnum, marks in ipairs(extmarks) do
		for _, mark in ipairs(marks) do
			vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, mark[1], mark[2])
		end
	end

	for match_start, match_end in gfind(text[4], "%(.-%)") do
		vim.api.nvim_buf_set_extmark(buf, ns, 3, match_start - 1, {
			end_col = match_end,
			hl_group = "JetSpecial",
		})
	end

	----------------------------------------------
	--                  Refresh                 --
	----------------------------------------------
	for lnum, l in ipairs(lines) do
		l:watch(function(line_text, marks)
			vim.schedule(function()
				vim.api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, { line_text })
				vim.api.nvim_buf_clear_namespace(buf, ns, lnum - 1, lnum)
				for _, mark in ipairs(marks) do
					vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, mark[1], mark[2])
				end
			end)
		end)
	end

	----------------------------------------------
	--                  Keymaps                 --
	----------------------------------------------
	vim.keymap.set("n", "q", function() vim.api.nvim_win_close(0, true) end)

	----------------------------------------------
	--               Display Buffer             --
	----------------------------------------------
	-- vim.bo[buf].modifiable = false

	local screen_width = vim.o.columns
	local screen_height = vim.o.lines
	local scale = function(x, y) return math.floor(x * y) end
	vim.api.nvim_open_win(buf, true, {
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
