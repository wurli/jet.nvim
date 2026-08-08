local M = {}

---@class jet.config
M.defaults = {
	jet_binary_path = nil, ---@type string?
	jet_library_path = nil, ---@type string?
	stop_on_buf_wipeout = true,
	stop_on_nvim_quit = true,
	auto_set_primary = true, ---@type boolean
	---key=filetype, value=kernelspec path
	---@type table<string, string | fun(): string?>
	default_kernels = {},
	repl_win_opts = {}, ---@type vim.api.keyset.win_config
	--- Control how Jet displays how long stuff is taking:
	--- ``` lua
	--- -- E.g. to display as hours, minutes, or seconds depending on the duration:
	--- require("jet").setup({
	---     time_formatter = function(hh, mm, ss)
	---         if hh > 0 then
	---             return string.format("%.1fh", hh + mm/60 + ss/(60 * 60))
	---         elseif mm > 0 then
	---             return string.format("%.1fm", mm + ss/60)
	---         else
	---             return string.format("%ds", ss)
	---         end
	---     end
	--- })
	--- ```
	ui = {
		stream_lines = 3, --- Number of lines from iopub stream to show in `:Jet` ui
	},
	time_formatter = nil, ---@type nil | fun(hh: integer, mm: integer, ss: integer): string
	hooks = {
		on_execution_state_changed = {}, ---@type table<string | integer, fun(k: jet.kernel, state: jet.kernel.execution_state)>
		on_kernel_close = {}, ---@type table<string | integer, fun(k: jet.kernel)>
		on_kernel_init = {}, ---@type table<string | integer, fun(k: jet.kernel)>
		on_lua_client_start = {}, ---@type table<string | integer, fun(k: jet.kernel)>
		on_message_received = {}, ---@type table<string | integer, fun(k: jet.kernel, msg: jet.jupyter.msg)>
		on_send_pre = {}, ---@type table<string | integer, fun(k: jet.kernel, code: string[])>
		on_status_changed = {}, ---@type table<string | integer, fun(k: jet.kernel)>
	},
	send = {
		---If `true` (the default) then each expression will be sent and
		---results shown one at a time. If `false`, then when sending several
		---complete expressions at once, all will be sent at once and results
		---will be shown afterwards.
		---
		---Some notes:
		---* If `true` then the Jet repl is run with `--no-indent`, otherwise
		---  when code is sent it might get double-indented. Not all kernels
		---  provide an indent, and ones that don't are not affected by the
		---  `--no-indent` option, but ipython notably *does* indent. So if
		---  you use `true` you might notice that you no longer get
		---  auto-indentation in the REPL.
		---* If `false` then expressions are sent surrounded by 'bracketed
		---  paste' escapes. This currently has a couple of downsides:
		---  - If the kernel is busy when code is sent, the escapes will be
		---    echoed in the REPL, resulting in some visual noise.
		---  - If too much code is sent at once (more than the height of the
		---    screen), it causes the REPL history to be truncated. This is due
		---    to an upstream issue in reedline, which powers the Jet REPL
		---    experience..
		send_by_expr = true, ---@type boolean
	},
}

M.jet_nvim_version = "0.0.1"

---@class jet.data
M.data = {
	jet_min_version = "0.0.5",
	jet_binary_path = nil, ---@type string?
	jet_library_path = nil, ---@type string?
	jet_nvim_data_dir = vim.fn.stdpath("data") .. "/jet",
}

---@type jet.config
M.options = nil

---@param options? Partial<jet.config>
function M.set(options)
	if options and options.jet_binary_path then
		local bin = vim.fs.abspath(options.jet_binary_path)
		assert(type(bin) == "string" and vim.fn.executable(bin) == 1, "jet_binary must be an executable")
		options.jet_binary_path = bin
	end

	M.options = vim.tbl_deep_extend("force", M.defaults, options or {})

	require("jet.core.utils.download").maybe_download_jet(function(res)
		M.data.jet_binary_path = res.bin_path
		M.data.jet_library_path = res.lib_path
	end)
end

return M
