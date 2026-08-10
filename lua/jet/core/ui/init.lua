local M = {}
local api = require("jet.core.api")
local utils = require("jet.core.utils")
local line = require("jet.core.ui.line")
local page = require("jet.core.ui.page")

local scale = function(x, y) return math.floor(x * y) end

local win_width = scale(vim.o.columns, 0.8)
local line_max_length = math.max(win_width - 10, 40)

---@param parts jet.ui.line.parts
local get_width = function(parts)
	local len = 0
	for _, part in ipairs(parts) do
		len = len + vim.fn.strwidth(part[1])
	end
	return len
end

local tbl_combine = function(...)
	local out = {}
	for _, t in ipairs({ ... }) do
		for _, e in ipairs(t) do
			table.insert(out, e)
		end
	end
	return out
end

---@param parts jet.ui.line.parts
local center = function(parts, indent)
	local pad_width = math.floor((win_width - get_width(parts) - (indent or 0) * 2) / 2)
	return tbl_combine({ { string.rep(" ", pad_width) } }, parts)
end

--- ``` lua
--- vim.print(truncate({ { "foofoo" }, { "barbar" }, { "bazbaz" } }, 10))
--- -- { { "foofoo" }, { "b" }, { "...", "JetDim1" } }
--- ```
---@param l jet.ui.line.parts
---@param max_len? integer
---@return jet.ui.line.parts
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
			table.insert(l, { "...", "JetDim1" })
			return l
		end
	end
	return l
end

---@param left jet.ui.line.parts
---@param right jet.ui.line.parts
---@param char? string
local divider = function(left, right, char)
	char = char or "·"
	local out_len = math.max(30, math.min(line_max_length, 80))
	local pad_left = { { char:rep(2), "JetDim2" } }
	local pad_right = { { char:rep(2), "JetDim2" } }

	local len = 0
	for _, slice in ipairs({ left, right, pad_left, pad_right }) do
		len = len + get_width(slice)
	end

	local pad_center = { { string.rep(char, math.max(out_len - len - 2, 0)), "JetDim2" } }
	return tbl_combine(pad_left, left, pad_center, right, pad_right)
end

local progress_icons = { "⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠" }
-- These look rubbish unfortunately
-- { "󰪞 ", "󰪟 ", "󰪠 ", "󰪡 ", "󰪢 ", "󰪣 ", "󰪤 ", "󰪥 " }

local make_progress_spinner = function()
	local index = 1
	return function()
		index = (index % #progress_icons) + 1
		---@diagnostic disable-next-line: undefined-field
		return progress_icons[index] .. " "
	end
end

---@param k jet.kernel
local active_kernel_line = function(k)
	assert(k.session_id, "Kernel must have a session_id")

	local next_progress_spinner = make_progress_spinner()

	return line.new({ indent = 3, timer = true, data = { kernel = k } }, function()
		assert(k.session_info, "Kernel must have session info")

		local status, status_icon = k:status()
		local parts = {}

		if status == "connecting" then
			table.insert(parts, { next_progress_spinner(), "JetBusy" })
		elseif status == "external" then
			table.insert(parts, { status_icon, "JetExternal" })
		elseif status == "connected" and k.last_execution and not k.last_execution.end_time then
			table.insert(parts, { status_icon, "JetBusy" })
		else
			table.insert(parts, { status_icon, "JetIdle" })
		end

		table.insert(parts, { (k.session_id or "") .. " ", "JetId" })
		table.insert(parts, { "(" .. utils.time_since(k.session_info.created_at) .. ") ", "Comment" })

		return parts
	end)
end

---@param name string
local kernel_group_line = function(name)
	return line.new({ indent = 1 }, function() return { { name, "JetH2" } } end)
end

---@param k jet.kernel
local kernel_info_line = function(k)
	return line.new(
		{ indent = 2, data = { kernel = k } },
		function()
			return {
				{ k.spec.display_name },
				{ "    " },
				{ utils.path_shorten(k.spec_path), "JetDim1" },
			}
		end
	)
end

local title_line = function()
	return line.new(
		{},
		function()
			return center({
				{ "jet.nvim", "JetH1" },
				{ " " },
				{ " ", { "JetH1", "Comment" } },
			})
		end
	)
end

local url_line = function()
	return line.new({}, function() return center({ { "https://github.com/wurli/jet", "JetUrl" } }) end)
end

local version_line = function()
	return line.new(
		{},
		function()
			return center({
				{ "plugin: " },
				{ require("jet.core.config").jet_nvim_version, "JetId" },
				{ " · " },
				{ "lib: " },
				{ require("jet.core.utils.download").check_lib_version().current, "JetId" },
			})
		end
	)
end

local keymaps_line = function()
	return line.new({ indent = 1 }, function()
		local map = function(name, key)
			name = string.format(" %s ", name)
			key = string.format("(%s) ", key)
			return { { name, "JetButton" }, { key, { "JetButton", "JetSpecial" } }, { "  " } }
		end
		return tbl_combine(
			map("Open", "o"),
			map("New session", "s"),
			map("Stop", "x"),
			map("Interrupt", "i"),
			map("Expand", "<CR>"),
			map("Quit", "q")
		)
	end)
end

local blank_line = function()
	return line.new({}, function() return { { "" } } end)
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
			line.new({ indent = 3 }, function() return { align("binary", 7), { k.spec.argv[1], "JetSpecial" } } end),
			blank_line(),
		}
	end

	---@type jet.ui.line<any>[]
	local out = {}

	if k.last_execution then
		local status_hl = function()
			return k.last_execution.is_error and "JetFailure" or k.last_execution.end_time and "JetSuccess" or "JetBusy"
		end

		local code = k.last_execution.code and k.last_execution.code:gsub("%s*$", "") or nil
		if code and code ~= "" then
			table.insert(
				out,
				line.new(
					{ indent = 4, timer = true },
					function()
						return divider({ { "in", "JetComment" } }, {
							{ "[", "JetDim2" },
							{ "#" .. k.last_execution.count, status_hl() },
							{ "]", "JetDim2" },
						})
					end
				)
			)

			for i, code_text in ipairs(vim.split(code, "\n")) do
				local code_line = line.new({}, function()
					local prefix = i == 1 and ">  " or "+  "
					local mark = {
						virt_text = { { "            " .. prefix, "JetDim1" } },
						virt_text_pos = "inline",
					}
					return { { code_text, mark, start_col = 0 } }
				end)
				if i == 1 and k.filetype then
					code_line.on_refresh.set_ts_extmarks = function(l)
						local hl = require("jet.core.ui.get_highlights").get_ts_highlights
						for _, mark in ipairs(hl(code, k.filetype, 0, l.lnum and l.lnum - 1)) do
							table.insert(l.marks, mark)
						end
					end
				end
				table.insert(out, code_line)
			end
		end

		local spinner = make_progress_spinner()
		for i = 1, k.iopub_stream.complete_lines:count() do
			if i == 1 then
				table.insert(out, blank_line())
				local divier_line = line.new({ indent = 4, timer = true }, function()
					local hl = status_hl()
					local icon = hl == "JetFailure" and " " or hl == "JetSuccess" and " " or spinner()
					return divider({ { "out", "JetComment" } }, {
						{ "[", "JetDim2" },
						{ icon .. utils.time_since(k.last_execution.start_time, k.last_execution.end_time), hl },
						{ "]", "JetDim2" },
					})
				end)
				table.insert(out, divier_line)
			end
			local stream_line = line.new({ timer = true }, function()
				local mark = {
					virt_text = { { "            •  ", "JetDim1" } },
					virt_text_pos = "inline",
				}
				return { { k.iopub_stream.complete_lines[i] or "", "JetCode" }, { "", mark, start_col = 0 } }
			end)
			table.insert(out, stream_line)
		end
	end

	if #out > 0 then
		table.insert(out, blank_line())
	end

	return out
end

---@type table<string, boolean>
local expanded_inactive_kernels = {}

---@param callback fun(lines: jet.ui.line[])
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
				lines = tbl_combine(lines, kernel_expand(group.kernel))
			end

			for _, k in ipairs(group.connected) do
				table.insert(lines, active_kernel_line(k))
				if k.ui_expand then
					lines = tbl_combine(lines, kernel_expand(k))
				end
				any_connected = true
			end

			for _, k in ipairs(group.external) do
				table.insert(lines, active_kernel_line(k))
				if k.ui_expand then
					lines = tbl_combine(lines, kernel_expand(k))
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

local ui_win = -99

M.show = function()
	if vim.api.nvim_win_is_valid(ui_win) then
		vim.api.nvim_set_current_win(ui_win)
		return
	end

	require("jet.core.ui.colours").setup()

	local ui = page.new({
		ns = vim.api.nvim_create_namespace("jet.ui"),
		get_lines = function(callback)
			kernel_lines(function(kernels)
				local lines = {
					blank_line(),
					title_line(),
					version_line(),
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
	})

	vim.bo[ui.buf].buftype = "nofile"
	vim.bo[ui.buf].filetype = "jetui"
	vim.bo[ui.buf].modifiable = false

	local hooks = require("jet.core.config").options.hooks
	hooks.on_status_changed.update_ui = function() ui:refresh() end
	hooks.on_kernel_close.collapse_ui = function(k) expanded_inactive_kernels[utils.path_normalise(k.spec_path)] = false end
	hooks.on_message_received.update_ui = function(k, msg)
		if
			k.ui_expand
			and msg.channel == "iopub"
			and k.iopub_stream.complete_lines.last <= k.iopub_stream.complete_lines._len
		then
			ui:refresh()
		end
	end

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

	vim.keymap.set("n", "i", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.kernel
			local k = l.data.kernel
			if k.client_id then
				k:interrupt()
			end
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

			vim.schedule(function() ui:refresh() end)
		end
	end, { buf = ui.buf })

	local next_kernel = function(direction)
		local lnum = vim.fn.line(".")
		for i = lnum + direction, direction == 1 and #ui.lines or 1, direction do
			if ui.lines[i] and ui.lines[i].data and ui.lines[i].data.kernel then
				vim.api.nvim_win_set_cursor(ui_win, { i, 0 })
				return
			end
		end
	end

	vim.keymap.set("n", "]]", function() next_kernel(1) end, { buf = ui.buf, desc = "[jet] go to next kernel" })
	vim.keymap.set("n", "[[", function() next_kernel(-1) end, { buf = ui.buf, desc = "[jet] go to previous kernel" })

	local screen_width = vim.o.columns
	local screen_height = vim.o.lines

	win_width = scale(screen_width, 0.8)
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
			hooks.on_message_received.update_ui = nil
		end,
	})

	vim.api.nvim_create_autocmd("WinResized", {
		pattern = tostring(ui_win),
		callback = function()
			win_width = vim.api.nvim_win_get_width(ui_win)
			line_max_length = math.max(win_width - 10, 40)
			ui:refresh()
		end,
	})
end

return M
