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
---@param mime jet.Mime
---@param filepath string
---@return boolean
M.base64_to_file = function(data, mime, filepath)
	if mime.type ~= "image" then
		utils.log_error("MIME type is not an image: %s/%s", mime.type, mime.subtype)
		return false
	end

	local handlers = require("jet.core.config").options.image.handlers
	local handler = handlers[mime.subtype]

	if handler then
		return handler(data, mime, filepath)
	end

	local supported_types = { png = true }
	if not supported_types[mime.subtype] then
		utils.log_error(
			"Unsupported MIME subtype '%s' (should be one of %s)",
			mime.subtype,
			table.concat(vim.list_extend(vim.tbl_keys(supported_types), vim.tbl_keys(handlers)), ", ")
		)
		return false
	end

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

	return true
end

---@param buf integer
---@param filepath string
M.show = function(buf, filepath)
	if not _G.Snacks then
		return
	end

	_G.Snacks.image.buf.attach(buf, {
		src = filepath,
		inline = true,
		type = "image",
		pos = { 1, 0 },
	})
end

return M
