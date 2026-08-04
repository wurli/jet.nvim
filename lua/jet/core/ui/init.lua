local M = {}
local api = require("jet.core.api")
local utils = require("jet.core.utils")
local line = require("jet.core.ui.line")
local page = require("jet.core.ui.page")

---@param k jet.kernel
local active_kernel_line = function(k)
	assert(k.session_id, "Kernel must have a session_id")
	local connecting_icons = { "⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠" }
	-- These look rubbish unfortunately
	-- { "󰪞 ", "󰪟 ", "󰪠 ", "󰪡 ", "󰪢 ", "󰪣 ", "󰪤 ", "󰪥 " }

	local connecting_icon_index = 1
	return line.new({
		indent = 2,
		interval = 100,
		alias = "Active kernel line " .. k.session_id,
		data = { kernel = k },
		make_parts = function()
			local status, status_icon = k:status()
			local icon

			if status == "connecting" then
				icon = connecting_icons[(connecting_icon_index % #connecting_icons) + 1] .. " "
				connecting_icon_index = connecting_icon_index + 1
			else
				icon = status_icon
			end

			assert(k.session_info, "Kernel must have session info")

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
				{ utils.path_shorten(k.spec_path), "Directory" },
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
				{ " New session (n) ", "JetButton" },
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
local kernel_info_lines = function(k)
	---@type jet.ui.line<any>[]
	local out = {}

	local bullet = { "• ", "Special" }

	if k.spec.argv and k.spec.argv[1] then
		table.insert(
			out,
			line.new({
				indent = 3,
				make_parts = function() return { bullet, { "Binary: ", "JetBold" }, { k.spec.argv[1], "JetSpecial" } } end,
			})
		)
	end

	if k.spec.env and vim.tbl_count(k.spec.env) > 0 then
		table.insert(
			out,
			line.new({
				indent = 3,
				make_parts = function()
					local envs = {}
					for name, val in pairs(k.spec.env) do
						table.insert(envs, name .. ": " .. val)
					end
					table.sort(envs)
					return {
						bullet,
						{ "Env: ", "JetBold" },
						{ table.concat(envs, ", ") },
					}
				end,
			})
		)
	end

	if k.iopub_last_line.text ~= "" then
		local stream_line = line.new({
			indent = 3,
			make_parts = function()
				return {
					bullet,
					{ "Stream: ", "JetBold" },
					{ k.iopub_last_line.text, "JetCode" },
				}
			end,
			on_unwatch = function() k.on_message_received.update_ui = nil end,
		})
		k.on_message_received.update_ui = function(_, msg)
			if msg.channel == "iopub" then
				stream_line:refresh()
			end
		end
		table.insert(out, stream_line)
	end

	return out
end

---@param callback fun(lines: jet.ui.line<jet.kernel>[])
local kernel_lines = function(callback)
	list_kernel_groups(function(groups)
		local lines = {}

		local group_name = ""

		for _, group in ipairs(groups) do
			local last_group = group_name
			group_name = (#group.connected > 0 or #group.external > 0) and "Active Kernels" or "Inactive Kernels"
			if group_name ~= last_group then
				table.insert(lines, kernel_group_line(group_name))
			end

			table.insert(lines, kernel_info_line(group.kernel))
			local any_connected = false
			for _, k in ipairs(group.connected) do
				table.insert(lines, active_kernel_line(k))
				if k.ui_expand then
					for _, l in ipairs(kernel_info_lines(k)) do
						table.insert(lines, l)
					end
				end
				any_connected = true
			end
			for _, k in ipairs(group.external) do
				table.insert(lines, active_kernel_line(k))
				if k.ui_expand then
					for _, l in ipairs(kernel_info_lines(k)) do
						table.insert(lines, l)
					end
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

	vim.keymap.set("n", "n", function()
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
			k:close()
		end
	end, { buf = ui.buf })

	vim.keymap.set("n", "<cr>", function()
		local l = ui.lines[vim.fn.line(".")]
		if l and l.data and l.data.kernel then
			---@type jet.kernel
			local k = l.data.kernel
			k.ui_expand = not k.ui_expand
			ui:refresh()
		end
	end, { buf = ui.buf })

	local screen_width = vim.o.columns
	local screen_height = vim.o.lines
	local scale = function(x, y) return math.floor(x * y) end
	ui_win = vim.api.nvim_open_win(ui.buf, true, {
		relative = "editor",
		width = scale(screen_width, 0.8),
		height = scale(screen_height, 0.8),
		row = scale(screen_height, 0.2 / 2),
		col = scale(screen_width, 0.2 / 2),
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(ui_win),
		callback = function() ui:close() end,
	})
end

return M
