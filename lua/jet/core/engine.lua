local lib_path = require("jet.core.config").data.library_path
assert(lib_path, "Could not resolve path to the Jet library")

local loader = package.loadlib(lib_path, "luaopen_jet")

assert(loader, "Could not load Jet library from " .. lib_path)

---@type Jet
local out = loader()

return out
