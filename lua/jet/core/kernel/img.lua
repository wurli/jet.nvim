local buf = require("jet.core.kernel.buf")

---@class jet.Kernel.Img : jet.Buf
---@field img_dir string
---@field img_file? string
local Img = setmetatable({}, { __index = buf })
Img.__index = Img ---@private

---@class jet.Kernel.Img.init.Opts
---@field session_id string
---@field display_name string
---@field ns integer
---@field img_dir string

---@param opts jet.Kernel.Img.init.Opts
---@return jet.Kernel.Img
function Img.init(opts)
	local session_hash = (opts.session_id or ""):match("_([^_]+)$")
	local buf_name = opts.display_name
	if session_hash then
		buf_name = buf_name .. " Images (" .. session_hash .. ")"
	end

	local out = buf.init(Img, {
		ns = opts.ns,
		name = buf_name,
		open_opts = function()
			local k = require("jet.core.manager").kernels[opts.session_id]
			local term_win = k and k.term and k.term:win()
			return term_win and {
				split = "above",
				win = term_win,
				style = "minimal",
			} or {
				split = "right",
				win = -1,
				style = "minimal",
			}
		end,
	})

	out.img_dir = opts.img_dir

	vim.keymap.set("n", "<c-n>", function() out:display(1) end, { buffer = out.buf })
	vim.keymap.set("n", "<c-p>", function() out:display(-1) end, { buffer = out.buf })

	return out
end

---@param focus? boolean
function Img:open(focus)
	buf.open(self, focus)
	self:display(self.img_file)
end

---@param file? string | 1 | -1
function Img:display(file)
	if not _G.Snacks then
		return
	end

	local filepath
	if type(file) == "string" then
		filepath = file
	else
		local files = {}
		local curr_file_index
		for name, type in vim.fs.dir(self.img_dir) do
			if type == "file" then
				table.insert(files, name)
				if name == self.img_file then
					curr_file_index = #files
				end
			end
		end

		if not curr_file_index or not file then
			filepath = files[#files]
		elseif file == 1 then
			filepath = files[curr_file_index + 1] or files[1]
		elseif file == -1 then
			filepath = files[curr_file_index - 1] or files[#files]
		end
	end

	if not filepath then
		return
	end

	self.img_file = vim.fs.basename(filepath)

	if not self:win() then
		return
	end

	_G.Snacks.image.buf.attach(self.buf, {
		src = vim.fs.joinpath(self.img_dir, filepath),
		inline = true,
		type = "image",
		pos = { 1, 0 },
	})
end

return Img
