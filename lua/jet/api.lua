local manager = require("jet.core.manager")
local motion = require("jet.core.send.motion")
local range_get = require("jet.core.send.get_range")

local M = {}

---@param opts? jet.send.next_expr_boundary.Opts
---@param p? jet.send.Pos
---@return jet.send.Pos?
M.next_expr_boundary = function(opts, p) return motion.next_expr_boundary(opts, p) end

---@param p? jet.send.Pos
---@return jet.send.Range?
M.get_expr = function(p) return range_get.get_expr(p) end

---Can be used in mappings to handle the code moved over by a motion:
---
---```lua
---vim.keymap.set(
--    { "n", "v" },
--    "gj",
--    require("jet.api").get_motion(vim.print),
--    { expr = true }
--)
---```
---
---@param callback fun(code: jet.send.Range, filetype: string?)
---@return fun(): "g@" # A function that can be used in an operator-pending mapping
M.handle_motion = function(callback) return range_get.handle_motion(callback) end

---@param filters? jet.api.Filters
---@param callback? fun(kernels: jet.Kernel[])
---@return jet.Kernel[]?
M.list_kernels = function(filters, callback) return manager.list(filters, callback) end

---Get a kernel and do some stuff with it
---
---Looks for kernels which match `filters` in the following order:
---1. Connected (or connecting) kernels
---2. Inactive kernels which are marked as 'default'
---3. Other inactive kernels
---
---If any of the above steps match a single kernel it is passed to
---`callback()`. If multiple kernels match, the user is prompted to select one.
---
---@param filters jet.api.Filters
---@param callback fun(k: jet.Kernel)
M.get_kernel = function(filters, callback) return manager.get(filters, callback) end

---Get a running kernel by its session id
---
---This can be useful, e.g. if you want to get the running `Kernel` object
---powering the repl:
---
---``` lua
---local jet = require("jet")
---local kernel = jet.get_by_id(vim.b.jet.session_id)
---```
---
---@param session_id string
---@return jet.Kernel?
M.get_kernel_by_id = function(session_id) return manager.get_by_id(session_id) end

return M
