local M = {}

---@class jet.Config.Hooks
---@field on_execution_state_changed table<any, fun(k: jet.Kernel, state: jet.kernel.execution_state)>
---@field on_kernel_close table<any, fun(k: jet.Kernel)>
---@field on_kernel_init table<any, fun(k: jet.Kernel)>
---@field on_lua_client_start table<any, fun(k: jet.Kernel)>
---@field on_message_received table<any, fun(k: jet.Kernel, msg: jupyter.Msg)>
---@field on_send_pre table<any, fun(k: jet.Kernel, code: string[])>
---@field on_status_changed table<any, fun(k: jet.Kernel)>

---@class jet.Config.Opts
M.defaults = {
	binary_path = nil, ---@type string? Path to a custom Jet binary.
	library_path = nil, ---@type string? Path to a custom Jet Lua library.
	---Set to `false` to keep the kernel running when the terminal buffer is
	---deleted - see |BufWipeout|.
	stop_on_buf_wipeout = true,
	stop_on_nvim_quit = true, ---Set to `false` to keep the kernel running when Neovim exits.
	auto_set_primary = true, ---@type boolean Set a kernel as primary when its repl is focussed.
	---Tell jet.nvim which kernel to use for a given filetype. E.g. to prefer
	---a python3 virtual env if present, use a function like so:
	---``` lua
	---default_kernels = {
	---    python = function()
	---        return vim.fs.find("kernel.json", {
	---            -- This requires the venv to have ipykernel installed!
	---            path = ".venv/share/jupyter/kernels/python3"
	---        })[1]
	---    end,
	---}
	---```
	---@type table<string, string | fun(): string?>
	default_kernels = {},
	repl_win_opts = {}, ---@type vim.api.keyset.win_config
	ui = {
		stream_lines = 3, --- Number of lines from iopub stream to show in `:Jet` ui
	},
	image = {
		handlers = {}, ---@type table<string, fun(data: string, mime: jet.Mime, filepath: string): boolean>
	},
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
	time_formatter = nil, ---@type nil | fun(hh: integer, mm: integer, ss: integer): string
	---These functions run at different points in the kernel lifecycle and can
	---be used to customise behaviour. For example, `on_message_received()`
	---triggers whenever a message is received from the kernel and is passed
	---the full message data. E.g. you could set up a notification whenever an
	---execution completes like so:
	---``` lua
	---require("jet").setup({
	---    hooks = {
	---        on_message_received = {
	---            my_notifier = function(k, msg)
	---                if msg.header.msg_type == "execute_reply" then
	---                    vim.notify(k.spec.display_name .. ": execution complete")
	---                end
	---            end
	---        }
	---    }
	---})
	---```
	---@type jet.Config.Hooks
	hooks = {
		on_execution_state_changed = {},
		on_kernel_close = {},
		on_kernel_init = {},
		on_lua_client_start = {},
		on_message_received = {},
		on_send_pre = {},
		on_status_changed = {},
	},
	---* `send.send_by_expr`: If `true` (the default) then each expression will
	---  be sent and results shown one at a time. If `false`, then when sending
	---  several complete expressions to the repl in one go, all will be
	---  executed together and results will be emitted after the input code.
	---  * If `true` then the Jet repl is run with `--no-indent`, otherwise
	---    when code is sent it might get double-indented. Not all kernels
	---    provide an indent, and ones that don't are not affected by the
	---    `--no-indent` option, but ipython notably *does* indent. So if you
	---    use `true` you might notice that you no longer get auto-indentation
	---    when writing multiline statements directly in the REPL.
	---  * If `false` then expressions are sent surrounded by 'bracketed paste'
	---    escapes. This currently has a couple of downsides:
	---    * If the kernel is busy when code is sent, the escapes will be
	---      echoed in the REPL, resulting in some visual noise.
	---    * If too much code is sent at once (more than the height of the
	---      screen), it causes the REPL history to be truncated. This is due
	---      to an upstream issue in reedline, which powers the Jet REPL
	---      experience..
	send = {
		send_by_expr = true, ---@type boolean
	},
}

M.jet_nvim_version = "0.0.1"

---@class jet.Config.Data
M.data = {
	jet_min_version = "0.0.7",
	binary_path = nil, ---@type string?
	library_path = nil, ---@type string?
	jet_nvim_data_dir = vim.fn.stdpath("data") .. "/jet",
}

---@type jet.Config.Opts
M.options = nil

---Sorry
---@alias jet.DeepPartial<T> { [P in keyof T]?: T[P] extends any[] and T[P] or (T[P] extends table and jet.DeepPartial<T[P]> or T[P]) }

---@param options? jet.DeepPartial<jet.Config.Opts>
function M.set(options)
	if options and options.binary_path then
		local bin = vim.fs.abspath(options.binary_path)
		assert(type(bin) == "string" and vim.fn.executable(bin) == 1, "jet_binary must be an executable")
		options.binary_path = bin
	end

	M.options = vim.tbl_deep_extend("force", M.defaults, options or {})

	require("jet.core.utils.download").maybe_download_jet(function(res)
		M.data.binary_path = res.bin_path
		M.data.library_path = res.lib_path
	end)
end

return M
