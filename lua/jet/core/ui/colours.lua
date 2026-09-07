local M = {}

---@class jet.Colours
M.colours = {
	JetBold = { bold = true },
	JetBusy = { link = "DiagnosticWarn" },
	JetButton = { link = "CursorLine" },
	JetCode = { link = "@markup.raw" },
	JetDim1 = { link = "Comment" },
	JetDim2 = { link = "ComplHint" },
	JetDim3 = { link = "WhiteSpace" },
	JetExternal = { link = "@variable.builtin" },
	JetFailure = { link = "DiagnosticError" },
	JetH1 = { link = "Title" },
	JetH2 = { link = "Bold" },
	JetId = { link = "Operator" },
	JetIdle = { link = "DiagnosticOk" },
	JetItalic = { italic = true },
	JetLabel = { link = "@label" },
	JetRepl = { link = "NormalFloat" },
	JetSpecial = { link = "@punctuation.special" },
	JetSuccess = { link = "DiagnosticOk" },
	JetUrl = { link = "@markup.link" },
}

M.set_highlights = function()
	for group, hl in pairs(M.colours) do
		---@diagnostic disable-next-line: inject-field
		hl.default = true
		vim.api.nvim_set_hl(0, group, hl)
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
