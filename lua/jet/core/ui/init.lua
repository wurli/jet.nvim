local M = {}
local api = require("jet.core.api")
local utils = require("jet.core.utils")
local line = require("jet.core.ui.line")
local page = require("jet.core.ui.page")

local line_max_length = 80

--- ``` lua
--- vim.print(truncate({ { "foofoo" }, { "barbar" }, { "bazbaz" } }, 10))
--- -- { { "foofoo" }, { "b" }, { "...", "JetDim" } }
--- ```
---@param l { [1]: string, [2]: string? }[]
---@param max_len? integer
---@return { [1]: string, [2]: string? }[]
local truncate = function(l, max_len)
	local l_len = 0
	max_len = max_len or line_max_length
	for _, part in ipairs(l) do
		l_len = l_len + #part[1]
	end
	if l_len <= max_len then
		return l
	end
	for i = #l, 1, -1 do
		local i_len = #l[i][1]
		if l_len - i_len + 3 > max_len then
			table.remove(l, i)
			l_len = l_len - i_len
		else
			local extra = max_len - l_len + i_len - 3
			l[i][1] = l[i][1]:sub(1, extra)
			table.insert(l, { "...", "JetDim" })
			return l
		end
	end
	return l
end

local progress_icons = { "⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠" }
-- These look rubbish unfortunately
-- { "󰪞 ", "󰪟 ", "󰪠 ", "󰪡 ", "󰪢 ", "󰪣 ", "󰪤 ", "󰪥 " }

local make_progress_spinner = function()
	local index = 1
	return function()
		index = (index % #progress_icons) + 1
		---@diagnostic disable-next-line: undefined-field
		return progress_icons[index]
	end
end

---@param k jet.kernel
local active_kernel_line = function(k)
	assert(k.session_id, "Kernel must have a session_id")

	local next_progress_spinner = make_progress_spinner()

	return line.new({
		indent = 3,
		timer = true,
		data = { kernel = k },
		make_parts = function()
			assert(k.session_info, "Kernel must have session info")

			local status, status_icon = k:status()
			local icon

			if status == "connecting" then
				icon = next_progress_spinner() .. " "
			else
				icon = status_icon
			end

			return {
				{ icon .. " ", status == "external" and "@variable.builtin" or "@string.regexp" },
				{ (k.session_id or "") .. " ", "JetId" },
				{ "(" .. utils.time_since(k.session_info.created_at) .. ") ", "Comment" },
			}
		end,
	})
end

---@param name string
local kernel_group_line = function(name)
	local out = line.new({
		indent = 1,
		make_parts = function() return { { name, "JetH2" } } end,
	})
	return out
end

---@param k jet.kernel
local kernel_info_line = function(k)
	return line.new({
		indent = 2,
		data = { kernel = k },
		make_parts = function()
			return {
				{ k.spec.display_name },
				{ "    " },
				{ utils.path_shorten(k.spec_path), "JetDim" },
			}
		end,
	})
end

local header_line = function()
	return line.new({
		indent = 1,
		make_parts = function() return { { "Jet ", "Title" }, { " ", "OkMsg" } } end,
	})
end

local url_line = function()
	return line.new({
		indent = 1,
		make_parts = function() return { { "https://github.com/wurli/jet", "JetUrl" } } end,
	})
end

local keymaps_line = function()
	return line.new({
		indent = 1,
		make_parts = function()
			return {
				{ " Open (o) ", "JetButton" },
				{ "  " },
				{ " New session (s) ", "JetButton" },
				{ "  " },
				{ " Stop (x) ", "JetButton" },
				{ "  " },
				{ " Quit (q) ", "JetButton" },
			}
		end,
	})
end

local blank_line = function()
	return line.new({
		make_parts = function() return { { "" } } end,
	})
end

---@class jet.ui.kernel_group
---@field kernel jet.kernel
---@field external jet.kernel[]
---@field connected jet.kernel[]

---@param callback fun(kernels: jet.ui.kernel_group[])
local list_kernel_groups = function(callback)
	api.list_kernels({}, {}, function(kernel_list)
		table.sort(kernel_list, function(a, b)
			if a:status() == "inactive" and b:status() ~= "inactive" then
				return true
			end
			return a.spec_path < b.spec_path
		end)

		---@type table<string, { kernel: jet.kernel, external: jet.kernel[], connected: jet.kernel[] }>
		local kernels_grouped = {}

		for _, k in ipairs(api.filter_kernels(kernel_list, { status = "inactive" })) do
			kernels_grouped[utils.path_normalise(k.spec_path)] = { kernel = k, external = {}, connected = {} }
		end

		for _, k in ipairs(api.filter_kernels(kernel_list, { status = { "connected", "connecting" } })) do
			local group = kernels_grouped[utils.path_normalise(k.spec_path)]
			---@diagnostic disable-next-line: unnecessary-assert
			assert(group, "Kernel group not found for kernel: " .. k.spec_path)
			table.insert(group.connected, k)
		end

		for _, k in ipairs(api.filter_kernels(kernel_list, { status = "external" })) do
			local group = kernels_grouped[utils.path_normalise(k.spec_path)]
			---@diagnostic disable-next-line: unnecessary-assert
			assert(group, "Kernel group not found for kernel: " .. k.spec_path)
			table.insert(group.external, k)
		end

		-- Makes sorting possible
		---@type jet.ui.kernel_group[]
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

		callback(out)
	end)
end

---@param k jet.kernel
---@return jet.ui.line<any>[]
local kernel_expand = function(k)
	local align = function(text, n) return { text .. string.rep(" ", (n or 12) - #text), "JetLabel" } end

	if k:status() == "inactive" and k.spec.argv and k.spec.argv[1] then
		return {
			line.new({
				indent = 3,
				make_parts = function() return { align("binary", 7), { k.spec.argv[1], "JetSpecial" } } end,
			}),
		}
	end

	---@type jet.ui.line<any>[]
	local out = {}

	-- if k:status() == "inactive" and k.spec.env and vim.tbl_count(k.spec.env) > 0 then
	-- 	table.insert(
	-- 		out,
	-- 		line.new({
	-- 			indent = 3,
	-- 			make_parts = function()
	-- 				local envs = {}
	-- 				for name, val in pairs(k.spec.env) do
	-- 					table.insert(envs, name .. ": " .. val)
	-- 				end
	-- 				table.sort(envs)
	-- 				return { align("env", 7), { table.concat(envs, ", ") } }
	-- 			end,
	-- 		})
	-- 	)
	-- end

	local code = k.last_execution and k.last_execution.code
	if code then
		---@type jet.ui.line[]
		local code_lines = {}
		for _, code_line in ipairs(vim.split(code, "\n")) do
			table.insert(
				code_lines,
				line.new({
					indent = 5,
					make_parts = function() return { { code_line } } end,
				})
			)
		end
		if code_lines[1] and k.filetype then
			code_lines[1].on_refresh.set_ts_extmarks = function(l)
				l.marks = require("jet.core.ui.get_highlights").get_ts_highlights(
					code,
					k.filetype,
					l.indent,
					l.lnum and l.lnum - 1
				)
			end
		end

		for _, l in ipairs(code_lines) do
			table.insert(out, l)
		end
	end

	table.insert(out, blank_line())

	local stream_line = line.new({
		indent = 5,
		timer = true,
		make_parts = function()
			local parts = {}
			if k.iopub_last_line.text == "" or not k.last_execution then
				table.insert(parts, { "n/a", "JetDim" })
			else
				table.insert(parts, { k.iopub_last_line.text, "JetCode" })
			end
			return truncate(parts)
		end,
	})

	local next_progress = make_progress_spinner()
	local timer_line = line.new({
		indent = 5,
		timer = true,
		make_parts = function()
			local parts = {}
			if not k.last_execution then
				table.insert(parts, { "-", "JetDim" })
				return truncate(parts)
			end
			local icon = k.last_execution.is_error and " "
				or k.last_execution.end_time and " "
				or next_progress() .. " "
			local elapsed = utils.time_since(k.last_execution.start_time, k.last_execution.end_time)
			table.insert(parts, { icon .. elapsed, "JetDim" })
			table.insert(parts, { " " })
			return truncate(parts)
		end,
	})

	k.on_message_received.update_ui = function(_, msg)
		if k.ui_expand and msg.channel == "iopub" then
			stream_line:refresh()
			timer_line:refresh()
		end
	end
	table.insert(out, stream_line)
	table.insert(out, timer_line)

	if #out > 0 then
		table.insert(out, blank_line())
	end

	return out
end

---@type table<string, boolean>
local expanded_inactive_kernels = {}

local tbl_append = function(x, y)
	for _, v in ipairs(y) do
		table.insert(x, v)
	end
end

---@param callback fun(lines: jet.ui.line<jet.kernel>[])
local kernel_lines = function(callback)
	list_kernel_groups(function(groups)
		local lines = {}

		local group_name = ""

		for _, group in ipairs(groups) do
			local prev_group = group_name
			group_name = (#group.connected > 0 or #group.external > 0) and "Active Kernels" or "Inactive Kernels"
			if group_name ~= prev_group then
				table.insert(lines, kernel_group_line(group_name))
			end

			local any_connected = false

			table.insert(lines, kernel_info_line(group.kernel))
			if expanded_inactive_kernels[utils.path_normalise(group.kernel.spec_path)] then
				tbl_append(lines, kernel_expand(group.kernel))
			end

			for _, k in ipairs(group.connected) do
				table.insert(lines, active_kernel_line(k))
				if k.ui_expand then
					tbl_append(lines, kernel_expand(k))
				end
				any_connected = true
			end

			for _, k in ipairs(group.external) do
				table.insert(lines, active_kernel_line(k))
				if k.ui_expand then
					tbl_append(lines, kernel_expand(k))
				end
				any_connected = true
			end

			if any_connected then
				table.insert(lines, blank_line())
			end
		end
		callback(lines)
	end)
end

-- 1. Global refresh (sets all lines)
-- 2. Line refresh (sets only one line)
--  - Triggered by the ui or the line object itself
--	- Needs the current line no - or could take a callback?
local ui_win = -99

M.show = function()
	if vim.api.nvim_win_is_valid(ui_win) then
		vim.api.nvim_set_current_win(ui_win)
		return
	end

	require("jet.core.ui.colours").setup()

	local ui = page.new({
		buf = vim.api.nvim_create_buf(false, true),
		ns = vim.api.nvim_create_namespace("jet.ui"),
		get_lines = function(callback)
			kernel_lines(function(kernels)
				local lines = {
					header_line(),
					url_line(),
					blank_line(),
					keymaps_line(),
					blank_line(),
				}
				for _, l in ipairs(kernels) do
					table.insert(lines, l)
				end
				callback(lines)
			end)
		end,
		-- Our abstractions only allow setting one layer of highlights, so just
		-- set additional highlights in a second pass by pattern matching.
		on_refresh = function(self)
			if not (self.text and self.text[4]) then
				return
			end
			for match_start, match_end in utils.gfind(self.text[4], "%(.%)") do
				vim.api.nvim_buf_set_extmark(self.buf, self.ns, 3, match_start - 1, {
					end_col = match_end,
					hl_group = "JetSpecial",
				})
			end
		end,
	})

	local hooks = require("jet.core.config").options.hooks
	hooks.on_status_changed.update_ui = function() ui:refresh() end
	hooks.on_kernel_close.collapse_ui = function(k) expanded_inactive_kernels[utils.path_normalise(k.spec_path)] = false end
	-- hooks.on_execution_state_changed.update_ui = function() ui:refresh() end

	vim.keymap.set("n", "q", function() vim.api.nvim_win_close(0, true) end, { buf = ui.buf })

	vim.keymap.set("n", "o", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.kernel
			local k = l.data.kernel
			k:open_term(function(_, focus_gained)
				if focus_gained then
					ui:close()
				end
			end)
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "s", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.kernel
			local k = l.data.kernel
			require("jet.core.kernel").init_owned({ spec_path = k.spec_path }):open_term()
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "x", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.kernel
			local k = l.data.kernel
			if k.session_id then
				k:close()
			end
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "<cr>", function()
		local l = ui.lines[vim.fn.line(".")]
		local k = l and l.data and l.data.kernel --[[@as jet.kernel]]
		if k then
			if k:status() == "inactive" then
				local path = utils.path_normalise(k.spec_path)
				expanded_inactive_kernels[path] = not expanded_inactive_kernels[path]
			else
				k.ui_expand = not k.ui_expand
			end

			ui:refresh()
		end
	end, { buf = ui.buf })

	local screen_width = vim.o.columns
	local screen_height = vim.o.lines
	local scale = function(x, y) return math.floor(x * y) end

	local win_width = scale(screen_width, 0.8)
	line_max_length = math.max(win_width - 10, 40)

	ui_win = vim.api.nvim_open_win(ui.buf, true, {
		relative = "editor",
		width = win_width,
		height = scale(screen_height, 0.8),
		row = scale(screen_height, 0.2 / 2),
		col = scale(screen_width, 0.2 / 2),
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(ui_win),
		callback = function()
			ui:close()
			hooks.on_status_changed.update_ui = nil
		end,
	})
end

return M
