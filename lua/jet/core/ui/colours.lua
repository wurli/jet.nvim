local M = {}

M.colours = {
	H1 = { link = "Title" },
	H2 = { link = "Bold" },
	Button = { link = "CursorLine" },
	Special = { link = "@punctuation.special" },
	Id = { link = "Operator" },
	Url = { link = "@markup.link" },
	Bold = { bold = true },
	Italic = { italic = true },
	Dim1 = { link = "Comment" },
	Dim2 = { link = "ComplHint" },
	Dim3 = { link = "WhiteSpace" },
	Code = { link = "@markup.raw" },
	Label = { link = "@label" },
	Repl = { link = "NormalFloat" },
	External = { link = "@variable.builtin" },
	Busy = { link = "DiagnosticWarn" },
	Success = { link = "DiagnosticOk" },
	Failure = { link = "DiagnosticError" },
	Idle = { link = "DiagnosticOk" },
}

M.set_highlights = function()
	for group, hl in pairs(M.colours) do
		---@diagnostic disable-next-line: inject-field
		hl.default = true
		vim.api.nvim_set_hl(0, "Jet" .. group, hl)
	end
end

M.did_setup = false

M.setup = function()
	---@diagnostic disable-next-line: unnecessary-if
	if M.did_setup then
		return
	end

	M.did_setup = true

	M.set_highlights()

	vim.api.nvim_create_autocmd("ColorScheme", {
		callback = M.set_highlights,
	})
end

return M
