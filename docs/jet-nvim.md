---
title: jet.nvim
filename: jet-nvim.txt
vimdoc-prefix: jet
---

jet.nvim is a Jupyter client/API for Neovim, built on top of
[Jet](https://github.com/wurli/jet).

## Configuration

Configure jet.nvim using `setup()`:

``` lua
require("jet").setup({
	-- Config here
})
```

The full set of configuration options is as follows:

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Ui
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Img
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Hooks
```

## Extensions

jet.nvim relies on extensions to provide language/kernel specific features.
Here's the current list of known extensions (if you create one please submit a
PR to extend this list!):

* jet.ark
  * Repo: https://github.com/wurli/jet.ark
  * Language: R
  * Features:
    * Full-featured LSP Server
    * Resizable plots
    * R "expression" resolution (see |jet-expression-textobject|)
    * In the future: variables/connections panes, DAP server
* jet.ipy
  * Repo: https://github.com/wurli/jet.ipy
  * Language: Python
  * Features:
    * Python "expression" resolution
    * Prioritisation on kernels in virtual environments

Also see |jet-extending-jet.nvim|.

## Setting keymaps

jet.nvim is unopinionated about how you should work with Jupyter kernels, and
therefore avoids setting global keymaps. The following keymaps are pretty sick
though:

### Toggle the repl

`get_kernel()` uses |vim.ui.select()| in the case when multiple kernels are
found. To avoid this you can either be more specific in the call to
`get_kernel()` (e.g. by passing an exact kernelspec path), or you could create
a hook which bumps a particular `Kernel`'s `priority`.

``` lua
local api = require("jet.api")

local toggle_repl = function(ft)
	return function()
		api.get_kernel({ filetype = ft }, function(k) k:term_toggle() end)
	end
end

vim.keymap.set("n", "<leader>jp", toggle_repl("python"), { desc = "Open Python (Jet)" })
vim.keymap.set("n", "<leader>jr", toggle_repl("r"), { desc = "Open R (Jet)" })
```

### Send code to the repl

The following keymap adds `go` as an operator which sends the current motion to
the repl. So, for example, `goi(` will send everything within the current
parentheses to an active jet repl matching the current filetype:

``` lua
vim.keymap.set(
	{ "n", "x" },
	"go",
	require("jet.api").handle_motion(function(range, filetype)
		require("jet.api").get_kernel({
			filetype = filetype,
			current = true,
			status = { "connected", "connecting" },
		}, function(k)
			local code = range:code({ comments = false })
			if code then
				k:send_repl(code)
			end
		end)
	end),
	{ desc = "Execute code (Jet)", expr = true }
)
```

### Expression textobject

For jet.nvim's purposes, an expression is just the smallest block of code
around (or ahead of) the cursor which it makes sense to send to the kernel in
one go. jet.nvim lets you configure how expressions are captured per-filetype;
this works great with `go` above, so with the combined mappings you could use
`goie` to send the current/next expression to the repl:

``` lua
local api = require("jet.api")

vim.keymap.set({ "x", "o" }, "ie", function()
	local expr = api.get_expr()
	if not expr then
		-- If there's no expression at the current position, skip ahead to the
		-- next one
		local pos = api.next_expr_boundary({
			current_ok = false,
			boundary = "start",
		})
		expr = pos and api.get_expr(pos)
	end
	if expr then
		expr:textobject()
	end
end, { desc = "textobject (jet): [i]n [e]xpression" })
```

### Go to expression

You can set keymaps (here `]e` and `[e`) to navigate between expressions:

``` lua
vim.keymap.set("n", "]e", function()
	local pos = api.next_expr_boundary({ direction = 1, boundary = "start" })
	if pos then
		vim.fn.cursor(pos:to_cursor())
	end
end)
vim.keymap.set("n", "[e", function()
	local pos = api.next_expr_boundary({ direction = -1, boundary = "start" })
	if pos then
		vim.fn.cursor(pos:to_cursor())
	end
end)
```

### Repl auto-send

If you like to blast through a script sending expressions to the repl as you
go, you could combine the above mappings to send the current expression and
move to the next one in a single keypress:

``` lua
vim.keymap.set("n", "<enter>", "goie]e", { remap = true })
vim.keymap.set("x", "<enter>", "go", { remap = true })
```

## Integrations

### Lualine

jet.nvim provides a lualine extension. This shows the kernel name plus:

* Busy status and execution duration (after a delay) for the repl window
* {Chart number}/{total number of produced charts} for the image window

Some config is exposed in `config.ui`. The extension needs to be enabled
explicitly:

``` lua
require("lualine").setup({ extensions = { "jet" } })
```

## UI

### Kernel management

`:Jet` without args brings up a UI for kernel management. This allows:

* Renaming sessions (sets the `Kernel.session_name` attribute)
* Stopping or starting kernels
* Connecting to kernels managed by Jet which are not owned by the current
  Neovim session
* Execution information (hit \<Enter\> over a running kernel to expand
  information)

### The repl buffer

The Jet repl buffer is just `jet start` (or `jet attach`) running in neovim's
built-in terminal.

`vim.b.jet.session_id` is set to the kernel's `session_id`. You can use this to
get the kernel itself - see |jet-api.get_kernel_by_id()|.

### Image display

When a connected kernel produces an image, jet.nvim saves the image to the
kernel's image directory (see |jet-Kernel:img_dir()|). The kernel image buffer
cycles through these saved images.

Image display works best when powered by snacks.nvim
(https://github.com/folke/snacks.nvim), but there is also basic support for
image.nvim (https://github.com/3rd/image.nvim). In the future jet.nvim will
migrate to Neovim's native image API.

You can open a kernel's image buffer using `Kernel:img_open()`.

## Filetypes

jet.nvim tries to determine the filetype of each running kernel, but may
occasionally fail to do so, or might guess the wrong filetype. In such cases you
can set the kernel filetype manually using hooks:

``` lua
-- Woxi is a jupyter kernel for the Wolfram language: https://github.com/ad-si/Woxi
local hooks = require("jet").hooks
hooks.on_kernel_init.set_woxi_filetype = function(k)
	if k.display_name:match("woxi") then
		k.filetype = "mma" -- mma ~ Wolfram Mathmatica
	end
end
```

## AI integration

AI agents can interact with your Jet session. To enable this:
1. Make sure the `jet` CLI is on the `PATH`
2. Install the jet skill (run `:!jet skill` to view the full skill text)

After this AI integration should "just work". You can confirm, e.g. by starting
a repl in jet.nvim and asking your agent of choice to "Say hi in my
\<language\> session using jet".

## Concepts

### Sessions

A Jet "session" is a running kernel, which can be connected to by multiple
clients. Jet assigns each session a unique `session_id` comprised of four
parts:

1. The session start date/time
2. The kernel language
3. The directory the kernel was started in
4. A random id

Each session gets a metadata `session.json` file stored in Jet's data dir. E.g.
on macOS the path to a `session.json` file might be
`~/.local/share/jet/2026-06-22_174223_python_cli_2c247e/session.json`. The
`session.json` stores stuff like

* The kernel process PID
* The session start time
* The path to the kernel's connection file, relative to the `session.json`

jet.nvim loads this data into each kernel's `session_info` field.

### Clients

A client is a frontend which connects to a kernel. If `Kernel.client_id` is
non-nil, then the Kernel is connected (the `client_id` is generated on
connection).

### Current kernels

jet.nvim tracks per-filetype "current" kernels. By default a kernel becomes
the current kernel for its filetype when:

* The kernel starts up, if there is not already a current kernel for the
  filetype
* the kernel's repl is focussed (i.e. on |TermEnter|)

Current status is basically a convenience mechanism for identifying the kernel
you're using "right now" in cases where you're running several kernels for a
given filetype. E.g. you can get the current kernel for the `python` filetype
like so:

``` lua
local api = require("jet.api")
api.get_kernel({ filetype = "python", current = true }, function(k)
	-- Do stuff with the kernel here
end)
```

You can set a kernel as current using `Kernel:set_current()`.

## Programming with jet.nvim

The Jupyter protocol is basically a standard for how interactive languages can
tell frontends about state and execution results. jet.nvim aims to create an
API for working with the Jupyter protocol using Neovim's Lua runtime. The key
parts of this api are:

1. The `api` module (|jet-jet.api|)
2. The Kernel class (|jet.Kernel|)

Also see |jet-recipes.txt| for more worked examples.

### The API module{#jet.api}

```{.sh include=true}
python3 scripts/emmylua-to-md.py --mod jet.api
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.api.Filters
```

### The Kernel Class

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Kernel
```

### Highlights

jet.nvim uses the following highlight groups, which can be overridden:

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Colours
```

## Versioning policy

I guess jet.nvim uses semver? Pin your install to a tagged version if you make
serious use of jet.nvim's Lua internals. From `0.1.0` we will strive to bump
the minor version for breaking changes.

TODO: think about how best to document changes. Use a `CHANGELOG.md`? 

## Extending jet.nvim

jet.nvim aims to delegate language/kernel specific features to extension
plugins, which may take advantage of jet.nvim's Lua abstractions and the
embedded Jet CLI/Lua library.

A typical extension may implement stuff like:

* Custom kernel configuration, e.g. handling kernel binary download and/or
  kernelspec creation
* A custom "expression" definition for a particular filetype to improve the
  behaviour of |jet-api.get_expr()| and friends.
* Handling of "comms" exposed by a particular kernel
  (https://jupyter-client.readthedocs.io/en/latest/messaging.html#custom-messages)
* Etc

An extension that does all the above is
[jet.ark](https://github.com/wurli/jet.ark).

### Custom filetype expressions

You can define a function which takes the current position (see |jet.send.Pos|)
and returns the range (see |jet.send.Range|) of the surrounding expression.
E.g. to set the python expression to the surrounding tree-sitter node:

``` lua
---@param pos jet.send.Pos
---@return jet.send.Range?
local get_python_expr = function(pos)
	local ok, node = pcall(vim.treesitter.get_node, {
		bufnr = pos.buf,
		pos = { pos.row, pos.col },
		ignore_injections = false,
	})
	if not ok or not node then
		return
	end

	local start_row, start_col, end_row, end_col = node:range(false)

	return require("jet.core.send.range").new({
		buf = pos.buf,
		start_row = start_row,
		start_col = start_col,
		end_row = end_row,
		end_col = end_col,
	})
end

local jet = require("jet")
jet.filetype.python = { get_expr = get_python_expr }
```
