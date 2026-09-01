local M = {}

M.init_hooks = function()
	---These functions run at different points in the kernel lifecycle and can
	---be used to customise behaviour. For example, `on_message_received()`
	---triggers whenever jet.nvim receives a message from the kernel, and it
	---receives the the full message data. You can use this to implement custom
	---behaviour, such as notifications which fire whenever an execution
	---completes, like so:
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
	---@class jet.Hooks
	local hooks = {
		---When the kernel switches between 'busy' and 'idle' status
		---@type table<any, fun(k: jet.Kernel, state: jet.Kernel.execution_state)>
		on_execution_state_changed = {},

		---After a Kernel is shut down
		---@type table<any, fun(k: jet.Kernel)>
		on_kernel_close = {},

		---After a Kernel object is initialised; before the Lua client or repl
		---actually start up. Can be useful, e.g. to set the kernel filetype or
		---session name.
		---@type table<any, fun(k: jet.Kernel)>
		on_kernel_init = {},

		---After the Lua client starts up.
		---@type table<any, fun(k: jet.Kernel)>
		on_lua_client_start = {},

		---Whenever a message is received from the kernel.
		---@type table<any, fun(k: jet.Kernel, msg: jupyter.Msg)>
		on_message_received = {},

		---Before sending code to the kernel. This callback can
		---modify the code to be sent in-place.
		---@type table<any, fun(k: jet.Kernel, code: string[])>
		on_send_pre = {},

		---When the kernel status changes (e.g. between 'connecting',
		---'connected', 'inactive' or 'external')
		---@type table<any, fun(k: jet.Kernel)>
		on_status_changed = {},

		---Before an image is displayed in Neovim
		---@type table<any, fun(k: jet.Kernel, file: string)>
		on_image_display_pre = {},

		---After a kernel's `primary` field is set to `true` or `false`
		---@type table<any, fun(k: jet.Kernel, primary: boolean)>
		on_primary_status_changed = {},
	}

	return hooks
end

local h = M.init_hooks()

---A rather grim implementation, but it gives type hints _and_ calls both the
---kernel-specific hooks and the global hooks.
---@generic T
---@param hooks table<string | integer, T>
---@return T
local function make_caller(hooks)
	local hook_name = ""
	for name, hook_table in pairs(h) do
		if hook_table == hooks then
			hook_name = name
			break
		end
	end

	assert(hook_name ~= "", "Could not determine which hook is being called")

	---@param k jet.Kernel
	return function(k, ...)
		local config_hooks = require("jet.core.config").options.hooks[hook_name]
		local kernel_hooks = k.hooks[hook_name]

		---@diagnostic disable-next-line: param-type-mismatch
		for _, hook in pairs(kernel_hooks) do
			hook(k, ...)
		end
		---@diagnostic disable-next-line: param-type-mismatch
		for _, hook in pairs(config_hooks) do
			hook(k, ...)
		end
	end
end

-- stylua: ignore start
M.do_execution_state_changed = make_caller(h.on_execution_state_changed)
M.do_kernel_close            = make_caller(h.on_kernel_close)
M.do_kernel_init             = make_caller(h.on_kernel_init)
M.do_lua_client_start        = make_caller(h.on_lua_client_start)
M.do_message_received        = make_caller(h.on_message_received)
M.do_send_pre                = make_caller(h.on_send_pre)
M.do_status_changed          = make_caller(h.on_status_changed)
M.do_image_display_pre       = make_caller(h.on_image_display_pre)
M.do_primary_status_changed  = make_caller(h.on_primary_status_changed)
-- stylua: ignore end

return M
