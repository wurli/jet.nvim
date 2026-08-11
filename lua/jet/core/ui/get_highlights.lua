---@param code string
---@param lang string
---@return jet.ui.line.extmark[]
local get_ts_highlights = function(code, lang)
	local ok, parser = pcall(vim.treesitter.get_string_parser, code, lang)

	if not ok then
		return {}
	end

	local trees = parser:parse()

	if not trees or #trees == 0 then
		return {}
	end

	local root = trees[1]:root()
	local query = vim.treesitter.query.get(lang, "highlights")

	if not query then
		return {}
	end

	---@type jet.ui.line.extmark[]
	local marks = {}

	for id, node, _ in query:iter_captures(root, code, 0, -1) do
		local capture = query.captures[id] -- e.g. "keyword", "string"
		local start_row, start_col, end_row, end_col = node:range()

		table.insert(marks, {
			start_row,
			start_col,
			{
				end_col = end_col,
				end_row = end_row,
				hl_group = "@" .. capture,
			},
		})
	end

	return marks
end

-- local code = {
-- 	"for _, l in ipairs({ 'foo', 'bar', 'baz' }) do",
-- 	"    print(l)",
-- 	"end",
-- }
--
-- vim.print(get_ts_highlights(code, "lua"))

return { get_ts_highlights = get_ts_highlights }
