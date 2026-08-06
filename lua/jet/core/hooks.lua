local M = {}

local h = require("jet.core.config").options.hooks

---@generic T
---@param hooks table<string | integer, T>
---@return T
local function make_caller(hooks)
	return function(...)
		for _, hook in ipairs(hooks) do
			hook(...)
		end
	end
end

-- stylua: ignore start
M.execution_state_changed = make_caller(h.on_execution_state_changed)
M.kernel_close            = make_caller(h.on_kernel_close)
M.kernel_init             = make_caller(h.on_kernel_init)
M.lua_client_start        = make_caller(h.on_lua_client_start)
M.message_received        = make_caller(h.on_message_received)
M.send_pre                = make_caller(h.on_send_pre)
M.status_changed          = make_caller(h.on_status_changed)
-- stylua: ignore end

return M
