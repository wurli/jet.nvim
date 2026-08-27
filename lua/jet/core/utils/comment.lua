local M = {}

---@param text string
---@param commentstring? string
---@return boolean
M.is_comment = function(text, commentstring)
	-- Happens reasonably often, so worth checking here for convenience
	if not commentstring or commentstring == "" then
		return false
	end

	local cs_left, cs_right = commentstring:match("^(.-)%s*%%s%s*(.-)$")

	if not (cs_left and cs_right) then
		return false
	end

	local startswith = function(s, prefix)
		if #prefix == 0 then
			return true
		end
		return s:sub(1, #prefix) == prefix
	end
	local endswith = function(s, suffix)
		if #suffix == 0 then
			return true
		end
		return s:sub(-#suffix) == suffix
	end

	text = vim.trim(text)
	return startswith(text, cs_left) and endswith(text, cs_right)
end

return M
