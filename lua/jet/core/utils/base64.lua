local utils = require("jet.core.utils")

local M = {}

---@param x string
---@param multiple integer
---@param pad string
---@return string
local pad_to_multiple = function(x, multiple, pad)
	local n_pad = (multiple - (#x % multiple)) % multiple
	return x .. pad:rep(n_pad)
end

---@param data string
---@return string
local base64_to_bytes = function(data)
	local clean = pad_to_multiple(data, 4, "=")
	return vim.base64.decode(clean)
end

---@param data string Base64-encoded data
---@param filepath string
---@return string | false
M.base64_to_file = function(data, filepath)
	local bytes = base64_to_bytes(data)

	local file, error = io.open(filepath, "wb")
	if not file then
		utils.log_error("Failed to write file `%s`: %s", filepath, error)
		return false
	end

	local ok, err = file:write(bytes)
	file:close()

	if not ok then
		utils.log_error("Failed to write file `%s`: %s", filepath, err)
		return false
	end

	return filepath
end

return M
