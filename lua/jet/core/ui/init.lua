local M = {}
local api = require("jet.core.api")
local utils = require("jet.core.utils")
local line = require("jet.core.ui.line")
local linegroup = require("jet.core.ui.linegroup")
local page = require("jet.core.ui.page")

local icons = {
	jet = " ",
	item_separator = " · ",
	divider = "·",
	progress = { "⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠" },
	primary = "★",
	failure = " ",
	success = " ",
}

local scale = function(x, y) return math.floor(x * y) end

local win_width = scale(vim.o.columns, 0.8)
local line_max_length = math.max(win_width - 10, 40)

---@generic T
---@param ... T[]
---@return T[]
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
local get_width = function(parts)
	local len = 0
	for _, part in ipairs(parts) do
		len = len + vim.fn.strwidth(part[1])
	end
	return len
end

---@param parts jet.ui.line.parts
local center = function(parts, indent)
	local pad_width = math.floor((win_width - (indent or 0) * 2 - get_width(parts)) / 2)
	return tbl_combine({ { string.rep(" ", pad_width) } }, parts)
end

---@param left? jet.ui.line.parts
---@param right? jet.ui.line.parts
local divider = function(left, right)
	left = left or {}
	right = right or {}
	local out_width = math.max(30, math.min(line_max_length, 80))
	local pad_left = { { icons.divider:rep(2), "JetDim3" } } --[[@as jet.ui.line.parts]]
	local pad_right = { { icons.divider:rep(2), "JetDim3" } }

	local width = get_width(left) + get_width(right) + get_width(pad_left) + get_width(pad_right)
	local pad_center = { { string.rep(icons.divider, math.max(out_width - width - 2, 0)), "JetDim3" } }

	return tbl_combine(pad_left, left, pad_center, right, pad_right)
end

local make_progress_spinner = function()
	local index = 1
	return function()
		index = (index % #icons.progress) + 1
		---@diagnostic disable-next-line: undefined-field
		return icons.progress[index] .. " "
	end
end

---@param k jet.Kernel
local kernel_info_line = function(k)
	return line.new({ indent = 2, data = { kernel = k } }, {
		{ k.spec.display_name },
		{ "    " },
		{ utils.path_shorten(k.spec_path), "JetDim2" },
	})
end

---@param k jet.Kernel
local session_info_line = function(k)
	assert(k.session_id, "Kernel must have a session_id")

	local next_progress_spinner = make_progress_spinner()

	return line.new({ indent = 2, data = { kernel = k } }, function()
		assert(k.session_info, "Kernel must have session info")

		local status, status_icon = k:status()
		local parts = {}

		local n_kernels_with_k_filetype = 0
		for _, kernel in pairs(require("jet.core.manager").kernels) do
			if kernel.filetype == k.filetype then
				n_kernels_with_k_filetype = n_kernels_with_k_filetype + 1
			end
		end

		local ft_for_which_k_is_primary = nil ---@type string?
		for ft, session_id in pairs(require("jet.core.manager").filetype_primary) do
			if session_id == k.session_id then
				ft_for_which_k_is_primary = ft
				break
			end
		end

		if ft_for_which_k_is_primary and n_kernels_with_k_filetype > 1 then
			table.insert(parts, { icons.primary .. " ", "JetSpecial" })
		else
			table.insert(parts, { "  " })
		end

		if status == "connecting" then
			table.insert(parts, { next_progress_spinner(), "JetBusy" })
		elseif status == "external" then
			table.insert(parts, { status_icon, "JetExternal" })
		elseif status == "connected" and k.last_execution and not k.last_execution.end_time then
			table.insert(parts, { status_icon, "JetBusy" })
		else
			table.insert(parts, { status_icon, "JetIdle" })
		end

		table.insert(parts, { (k.session_name or k.session_id or "") .. " ", "JetId" })
		table.insert(parts, { "(" .. utils.time_since(k.session_info.created_at) .. ") ", "JetDim1" })

		return parts
	end)
end

local title_line = function()
	return line.new(
		{},
		function()
			return center({
				{ "jet.nvim", "JetH1" },
				{ " " },
				{ icons.jet, { "JetH1", "JetDim1" } },
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
				{ icons.item_separator },
				{ "lib: " },
				{ require("jet.core.utils.download").check_lib_version().current, "JetId" },
			})
		end
	)
end

local keymaps_line = function()
	local map = function(name, key)
		name = string.format(" %s ", name)
		key = string.format("(%s) ", key)
		return { { name, "JetButton" }, { key, { "JetButton", "JetSpecial" } }, { "  " } }
	end
	return line.new(
		{ indent = 1 },
		tbl_combine(
			map("Open", "o"),
			map("New session", "s"),
			map("Stop", "x"),
			map("Interrupt", "i"),
			map("Rename session", "r"),
			map("Expand", "<CR>"),
			map("Quit", "q")
		)
	)
end

local execution_in_progress_spinner = make_progress_spinner()

---@type table<string, boolean>
local expanded_inactive_kernels = {}

---@param k jet.Kernel
---@return jet.ui.line[]
local expand_inactive = function(k)
	if not expanded_inactive_kernels[utils.path_normalise(k.spec_path)] then
		return {}
	end
	local cmd = k.spec.argv and k.spec.argv[1] or nil

	if not cmd then
		return {}
	end

	return {
		line.new({ indent = 3 }, { { "binary ", "JetLabel" }, { cmd, "JetSpecial" } }),
		line.new(),
	}
end

---@param k jet.Kernel
---@return jet.ui.line[]
local expand_active = function(k)
	if not k.ui_expand then
		return {}
	end

	---@type jet.ui.line<any>[]
	local out = {}

	local status_hl = function()
		if not k.last_execution then
			return "JetIdle"
		elseif k.last_execution.is_error then
			return "JetFailure"
		elseif k.last_execution.end_time then
			return "JetSuccess"
		else
			return "JetBusy"
		end
	end

	if k.session_name and k.session_id then
		table.insert(out, line.new({ indent = 4 }, { { "session id ", "JetLabel" }, { k.session_id, "JetId" } }))
		table.insert(out, line.new())
	end

	if k.last_execution then
		local code = k.last_execution.code and k.last_execution.code:gsub("%s*$", "") or nil
		if code and code ~= "" then
			table.insert(
				out,
				line.new(
					{ indent = 4 },
					function()
						return divider({ { "in", "JetDim1" } }, {
							{ "[", "JetDim3" },
							{ "#" .. k.last_execution.count, status_hl() },
							{ "]", "JetDim3" },
						})
					end
				)
			)

			for i, code_text in ipairs(vim.split(code, "\n")) do
				local code_line = line.new({}, function()
					local prefix = i == 1 and ">  " or "+  "
					local mark = {
						virt_text = { { "            " .. prefix, "JetDim2" } },
						virt_text_pos = "inline",
					}
					return { { code_text, mark, start_col = 0 } }
				end)
				if i == 1 and k.filetype then
					code_line.on_resolve = function(l)
						local hl = require("jet.core.ui.get_highlights").get_ts_highlights
						l.marks = tbl_combine(l.marks, hl(code, k.filetype))
					end
				end
				table.insert(out, code_line)
			end

			table.insert(out, line.new())
		end
	end

	local divider_line = line.new({ indent = 4 }, function()
		local hl = status_hl()

		local icon = hl == "JetFailure" and icons.failure
			or hl == "JetSuccess" and icons.success
			or execution_in_progress_spinner()

		return divider({ { "out", "JetDim1" } }, k.last_execution and {
			{ "[", "JetDim3" },
			{ icon .. utils.time_since(k.last_execution.start_time, k.last_execution.end_time), hl },
			{ "]", "JetDim3" },
		})
	end)
	table.insert(out, divider_line)

	local stream = k.output_stream.complete_lines:items()
	local output_indent = { virt_text = { { "            •  ", "JetDim2" } }, virt_text_pos = "inline" } --[[@as vim.api.keyset.set_extmark]]

	if #stream == 0 then
		local no_output_line = line.new({}, { { "No kernel output", "JetDim1" }, { "", output_indent, start_col = 0 } })
		table.insert(out, no_output_line)
	else
		for _, output_line in ipairs(stream) do
			local stream_line = line.new({}, function()
				local parts = { { output_line, "JetCode" }, { "", output_indent, start_col = 0 } }
				return parts
			end)
			table.insert(out, stream_line)
		end
	end

	if #out == 0 then
		table.insert(out, line.new({ indent = 4 }, { { "> No output yet", "JetDim2" } }))
	end
	table.insert(out, line.new())

	return out
end

---@class jet.ui.kernel_group
---@field kernel jet.Kernel
---@field external jet.Kernel[]
---@field connected jet.Kernel[]

---@param callback fun(kernels: jet.ui.kernel_group[])
local list_kernel_groups = function(callback)
	api.list_kernels({}, {}, function(kernel_list)
		table.sort(kernel_list, function(a, b)
			if a:status() == "inactive" and b:status() ~= "inactive" then
				return true
			end
			return a.spec_path < b.spec_path
		end)

		---@type table<string, { kernel: jet.Kernel, external: jet.Kernel[], connected: jet.Kernel[] }>
		local kernels_grouped = {}

		for _, k in ipairs(api.filter_kernels(kernel_list, { status = "inactive" })) do
			kernels_grouped[utils.path_normalise(k.spec_path)] = { kernel = k, external = {}, connected = {} }
		end

		for group_name, kernels in pairs({
			connected = api.filter_kernels(kernel_list, { status = { "connected", "connecting" } }),
			external = api.filter_kernels(kernel_list, { status = "external" }),
		}) do
			for _, k in ipairs(kernels) do
				local path = utils.path_normalise(k.spec_path)
				kernels_grouped[path] = kernels_grouped[path] or { kernel = k, external = {}, connected = {} }
				local group = kernels_grouped[path]
				---@diagnostic disable-next-line: unnecessary-assert
				assert(group, "Kernel group not found for kernel: " .. k.spec_path)
				---@diagnostic disable-next-line: undefined-field
				table.insert(group[group_name], k)
			end
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

---@param callback fun(groups: jet.ui.linegroup[])
local make_kernel_linegroups = function(callback)
	list_kernel_groups(function(kernel_groups)
		local group_title = ""
		local groups = {}

		for _, group in ipairs(kernel_groups) do
			local prev_group_title = group_title
			group_title = (#group.connected > 0 or #group.external > 0) and "Active Kernels" or "Inactive Kernels"

			if group_title ~= prev_group_title then
				table.insert(groups, linegroup.new({ line.new({ indent = 1 }, { { group_title, "JetH2" } }) }))
			end

			table.insert(groups, linegroup.new({ kernel_info_line(group.kernel) }))
			table.insert(groups, linegroup.new(function() return expand_inactive(group.kernel) end))

			local any_active = false
			for _, kernels in ipairs({ group.connected, group.external }) do
				for _, k in ipairs(kernels) do
					any_active = true
					table.insert(groups, linegroup.new({ session_info_line(k) }))
					table.insert(groups, linegroup.new(function() return expand_active(k) end))
				end
			end

			if any_active then
				table.insert(groups, linegroup.new({ line.new() }))
			end
		end

		callback(groups)
	end)
end

local ui_win = -99

M.show = function()
	if vim.api.nvim_win_is_valid(ui_win) then
		vim.api.nvim_set_current_win(ui_win)
		return
	end

	require("jet.core.ui.colours").setup()

	local ui = page.new({ ns = vim.api.nvim_create_namespace("jet.ui") }, function(callback)
		local header_group = linegroup.new({
			line.new(),
			title_line(),
			version_line(),
			url_line(),
			line.new(),
			keymaps_line(),
			line.new(),
		})

		make_kernel_linegroups(function(groups)
			table.insert(groups, 1, header_group)
			callback(groups)
		end)
	end)

	vim.bo[ui.buf].buftype = "nofile"
	vim.bo[ui.buf].filetype = "jetui"
	vim.bo[ui.buf].modifiable = false

	local hooks = require("jet.core.config").options.hooks
	hooks.on_status_changed.update_ui = function() ui:refresh() end
	hooks.on_kernel_close.collapse_ui = function(k) expanded_inactive_kernels[utils.path_normalise(k.spec_path)] = false end

	-- If a kernel block is expanded, some messages may cause the expanded
	-- block to grow/shrink. In such cases we redraw the whole UI - this is
	-- expensive though, so we want to be as accurate as possible when
	-- detecting cases which should cause a change in size.
	hooks.on_message_received.update_ui = function(k, msg)
		if not k.ui_expand or not msg.channel == "iopub" then
			return
		end
		-- If the stream is not 'full' yet then just redraw every time we get
		-- an iopub message. This triggers a few unnecessary redraws, but only
		-- if the user sets a bunch of code running and immediately opens the
		-- UI - an edge cases.
		if k.output_stream.complete_lines.last <= k.output_stream.complete_lines._len then
			ui:redraw()
			return
		end
		-- Update when the last executed code changes
		if msg.header.msg_type == "execute_input" then
			local code = k.last_execution and k.last_execution.code
			if not code then
				return
			end
			ui:redraw()
		end
	end

	vim.keymap.set("n", "q", function() vim.api.nvim_win_close(0, true) end, { buf = ui.buf })

	vim.keymap.set("n", "o", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.Kernel
			local k = l.data.kernel
			local should_focus = k.term and k.term:win()
			k:open_term(function()
				if should_focus then
					ui:close()
				end
			end, true)
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "s", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.Kernel
			local k = l.data.kernel
			require("jet.core.kernel").init_owned({ spec_path = k.spec_path }):open_term()
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "i", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.Kernel
			local k = l.data.kernel
			if k.client_id then
				k:interrupt()
			end
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "x", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.Kernel
			local k = l.data.kernel
			if k.session_id then
				k:close()
			end
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "r", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel and l.data.kernel.session_id then
			---@type jet.Kernel
			local k = l.data.kernel
			vim.ui.input({
				prompt = "Set session name: ",
				default = k.session_name or "",
				-- Note: right now highlighting doesn't show up if require("vim._core.ui2").enable({})
				highlight = function(text) return { { 0, #text, "JetId" } } end,
			}, function(input)
				if input then
					k.session_name = input ~= "" and input or nil
					ui:redraw()
				end
			end)
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "<cr>", function()
		local l = ui.lines[vim.fn.line(".")]
		local k = l and l.data and l.data.kernel --[[@as jet.Kernel]]
		if k then
			if k:status() == "inactive" then
				local path = utils.path_normalise(k.spec_path)
				expanded_inactive_kernels[path] = not expanded_inactive_kernels[path]
			else
				k.ui_expand = not k.ui_expand
			end

			ui:redraw()
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

	-- The UI runs a timer which is moderately expensive, so just nuke the
	-- whole UI when it's not visible
	vim.api.nvim_create_autocmd({ "WinClosed", "BufWinLeave" }, {
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
			ui:redraw()
		end,
	})
end

return M
