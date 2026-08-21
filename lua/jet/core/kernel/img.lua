local buf = require("jet.core.kernel.buf")

---@class jet.Kernel.Img : jet.Buf
---@field kernel jet.Kernel
---@field img_file? string
local Img = setmetatable({}, { __index = buf })
Img.__index = Img ---@private

---@class jet.Kernel.Img.init.Opts
---@field kernel jet.Kernel
---@field ns integer

---@param opts jet.Kernel.Img.init.Opts
---@return jet.Kernel.Img
function Img.init(opts)
	assert(opts.kernel.session_id, "Kernel session_id is required")

	local session_hash = opts.kernel.session_id:match("_([^_]+)$")
	local buf_name = opts.kernel.spec.display_name
	if session_hash then
		buf_name = buf_name .. " (" .. session_hash .. ") - Images"
	end

	local out = buf.init(Img, {
		name = buf_name,
		ns = opts.ns,
		open_opts = function()
			local term_win = opts.kernel.term and opts.kernel.term:win()
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

	out.kernel = opts.kernel
	vim.bo[out.buf].filetype = "jetimg"
	vim.b[out.buf].jet = { session_id = out.kernel.session_id }

	out:create_autocmd("BufWinEnter", function() out:display() end)

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
		for name, type in vim.fs.dir(self.kernel:image_dir()) do
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
		src = vim.fs.joinpath(self.kernel:image_dir(), filepath),
		inline = true,
		type = "image",
		pos = { 1, 0 },
	})
end

return Img
