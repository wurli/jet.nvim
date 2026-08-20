---@generic T
---@class jet.utils.Queue<T> : T[]
---@field _items T[]
---@field first integer
---@field last integer
---@field _len integer
local Queue = {}
Queue.__index = function(q, k)
	if type(k) == "number" then
		return q._items[q.first + k - 1]
	end
	return Queue[k]
end

---@param v T
Queue.__newindex = function(q, k, v)
	assert(type(k) == "number")
	if k < 1 or k > q.len then
		error(string.format("Can't assign to index %s (outside of [1, %s])", k, q.len))
	end
	q.items[q.first + k - 1] = v
end

---Add an item to the end of the queue, maybe pushing one out from the front
---@param x T
function Queue:append(x)
	if self.last - self.first + 1 >= self._len then
		self._items[self.first] = nil
		self.first = self.first + 1
	end
	self.last = self.last + 1
	self._items[self.last] = x
end

---Add an item to the front of the queue, maybe pushing one out from the end
---@param x T
function Queue:prepend(x)
	if self.last - self.first + 1 >= self._len then
		self._items[self.last] = nil
		self.last = self.last - 1
	end
	self.first = self.first - 1
	self._items[self.first] = x
end

---@return T[]
function Queue:items()
	local out = {}
	for i = self.first, self.last do
		table.insert(out, self._items[i])
	end
	return out
end

function Queue:count() return self.last - self.first + 1 end

--- ``` lua
--- local q = M.queue(3, {} --[[@as string[] ]])
--- q:append("hi")
--- q:append("there")
--- q:append("esteemed")
--- q:append("user")
--- vim.print(q:items())
--- -- { "there", "esteemed", "user" }
--- ```
---@generic U
---@param len integer
---@param items U[]
---@return jet.utils.Queue<U>
Queue.new = function(len, items)
	return setmetatable({
		_items = items or {},
		_len = len,
		first = 1,
		last = 0,
	}, Queue)
end

return Queue
