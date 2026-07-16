local lib_path = require("jet.config").data.jet_library_path
assert(lib_path, "Could not resolve path to the Jet library")

local loader = package.loadlib(lib_path, "luaopen_jet")

---@type jet.engine
local out = loader()

return out
