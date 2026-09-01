# <p align="center">jet.nvim ✈️</p>

<p align="center">A Jupyter kernel supervisor for Neovim, built on top of <a href=https://github.com/wurli/jet>Jet</a></p>

<!-- ![demo](https://github.com/user-attachments/assets/3e091499-eee3-43d8-ad75-8bfa7a2113f7) -->
https://github.com/user-attachments/assets/940430ed-f0f3-498c-807e-efa6ae85cf86

## Features

*   A repl which runs in Neovim's built-in terminal
*   An LSP server which provides live completions from the kernel
*   A Lua API with fine-grained control over running kernels, down to the level
    of individual Jupyter messages
*   Ability to connect to kernel sessions running outside of Neovim
*   AI-friendly: agents can use the Jet CLI to interact with your kernel
    sessions
*   Plug and play - No remote plugin stuff. No python requirements. 

**Not yet implemented**
*   Notebooks
*   Windows support (contributions welcome!)

## More demos

<details>
<summary><strong>Send from buffer using custom motions/textobjects</strong></summary>

jet.nvim provides an 'expression' text object, which can be used to send
discrete chunks of code to the Jet repl. The textobject is configurable per
filetype, so for example, installing jet.nvim extensions like
[jet.ark](https://github.com/wurli/jet.ark) will give better expression
detection in R scripts.

In the demo below, `]e` and `[e` are used to go the next/previous expression,
and `ie` is used as the expression textobject. These compose nicely, so e.g.
the following keymap can be used to send the current expression to the repl
with a single keypress:

``` lua
vim.keymap.set("n", "<enter>", "goie]e", { remap = true })
```

![motions](https://github.com/user-attachments/assets/f9c58f37-f084-43c4-9f33-413f26f016d3)

</details>

<details>
<summary><strong>AI integration</strong></summary>

The [Jet CLI](https://github.com/wurli/jet) allows multiple users to connect to
the same kernel session. Jet provides a simple
[skill](https://github.com/wurli/jet/blob/main/crates/cli/src/skill.md)
teaching AI agents how to do this. Agent code is clearly marked as such in the
repl:

![claude](https://github.com/user-attachments/assets/0d34eefe-db6f-43f8-b58f-34abea99ada7)

**Why is this kind of AI integration useful?** Say you have some Python code
which produces a single DataFrame and takes 10 minutes to run. Once you have
the resulting DataFrame loaded in your Python session, to perform any analysis
using AI in a traditional workflow, you will either need to first tell the AI
how to reproduce the DataFrame, or serialise it to a file which the AI can
quickly read. Both of these options take time and introduce plenty of room for
things to go wrong. Using Jet however, the AI acts as 'player 2' in your
session and can work with the data directly. This can save a tonne of time and
greatly reduce context/token usage for certain types of problem.

bla bla

</details>

<details>
<summary><strong>LSP Server</strong></summary>

jet.nvim provides kernel completions via an LSP middle-layer. These can include
runtime information not available to other LSP servers, e.g. the column names in
a Pandas DataFrame:

![completions](https://github.com/user-attachments/assets/37322d81-1972-42fd-9b79-eaaf5692bb2b)

</details>


<details>
<summary><strong>Jet UI</strong></summary>

jet.nvim provides a UI for kernel management, allowing you to easily
start, stop or rename kernel sessions from Neovim:

![ui](https://github.com/user-attachments/assets/dae00ec1-59cf-490a-9536-7be2973e64bd)

</details>

## Installation

Using `vim.pack`:

``` lua
vim.pack.add({ "https://github.com/wurli/jet.nvim" })
require("jet").setup({})
```

This will enable the `:Jet` command to bring up the jet.nvim kernel management
UI.

Since most users will want to work with running kernels in different ways,
jet.nvim avoids setting default keymaps and instead aims to provide a flexible,
low-level Lua API to allow users to implement the behaviour that works for
_them_. The following mappings should give some idea of what's possible:

<details>
<summary>Repl togglers by filetype</summary>

jet.nvim supports running many kernels simultaneously, and each kernel may also
run many instances. `get_kernel()` uses some heuristics to determine the best
kernel to use; see the docs for more information:

``` lua
local toggle_repl = function(ft)
	return function()
		require("jet.api").get_kernel({ filetype = ft }, function(k) k:term_toggle() end)
	end
end

vim.keymap.set("n", "<leader>jp", toggle_repl("python"), { desc = "Open Python (Jet)" })
vim.keymap.set("n", "<leader>jr", toggle_repl("r"), { desc = "Open R (Jet)" })
```

</details>

<details>
<summary>Toggle image window</summary>

The Jet repl and image buffers set `vim.b.jet.session_id`, which can be used to
get the `Kernel` object which 'owns' the buffers. This mechanism can be used to
set toggle keymaps like so:

``` lua
vim.api.nvim_create_autocmd("BufWinEnter", {
	callback = function()
		local session_id = vim.b.jet and vim.b.jet.session_id
		local k = session_id and require("jet.api").get_kernel_by_id(session_id)
		if k then
			vim.keymap.set({ "n", "t" }, "<c-o>", function() k:img_toggle() end, { buffer = 0 })
		end
	end,
})
```
</details>

<details>
<summary>Send code to the repl</summary>

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
			primary = true,
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
</details>

<details>
<summary>'Expression' textobject</summary>

Jet allows you to configure what a current 'expression' looks like for a given
language. For jet.nvim's purposes, an expression is just the smallest block of
code around (or ahead of) the cursor which it makes sense to send to the kernel
in one go. This works great with `go` above, so with the combined mappings you
could use `goie` to send the current/next expression to the repl:

``` lua
local api = require("jet.api")

vim.keymap.set({ "x", "o" }, "ie", function()
	local expr = api.get_expr()
	if not expr then
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

`]e` and `[e` can be used to navigate between 'expressions':

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

Finally, if you like to blast through a script sending expressions to the repl
as you go, you might like a mapping to send the current expression and move to
the next one in a single keypress:

``` lua
vim.keymap.set("n", "<enter>", "goie]e", { remap = true })
vim.keymap.set("x", "<enter>", "go", { remap = true })
```

</details>


## Extending jet.nvim

jet.nvim exposes an [API](./lua/jet/core/kernel.lua) for working with Jupyter
kernels using Lua. The idea is to allow other plugins to build on jet.nvim to
expose kernel-specific functionality. 

**Existing extensions**

| Repo                                        | Kernel                                  | Language | Features             |
| ----                                        | ------                                  | -------- | --------             |
| [jet.ark](https://github.com/wurli/jet.ark) | [Ark](https://github.com/posit-dev/ark) | R        | LSP server, debugger |

## Similar plugins

Many other plugins provide some level of Jupyter integration, mostly by
implementing a Python backend. jet.nvim takes a different approach, offloading
implementation details such as ZMQ and Jupyter's wire protocol to Jet's Rust
backend. This happens in two ways:

* **Jet's Lua API**: jet.nvim bundles the Jet Lua library, allowing a fully
  featured kernel supervisor to be built in Neovim's Lua runtime. This makes
  jet.nvim more extensible than any other Jupyter plugin in Neovim's ecosystem,
  and allows jet.nvim itself to stay fairly lean, delegating kernel-specific
  problems to extension plugins such as
  [jet.ark](https://github.com/wurli/jet.ark).

* **Jet's CLI**: Jet provides a command-line tool implementing a full,
  completion-enabled repl which runs in any terminal emulator. jet.nvim runs
  the Jet CLI in Neovim's built-in terminal to provide a repl experience which
  _feels_ like native Neovim. A bonus of this architecture is that, since any
  number of Jet processes can connect to a single kernel instance, any AI agent
  can also connect to your kernel session and run code, evaluate results, etc
  alongside you.

Architecture differences aside, a high-level feature comparison is as follows:

<table>
  <thead>
    <tr>
      <th>Plugin</th>
      <th>Backend</th>
      <th>Rich Lua API</th>
      <th>Image support</th>
      <th>Native terminal repl</th>
      <th>Custom UI</th>
      <th>LSP</th>
      <th>Notebook support</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align = "center">
          <strong>jet.nvim</strong>
          <br/>
          <img src="https://img.shields.io/github/stars/wurli/jet.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">Backed by <a href="https://github.com/wurli/jet">Jet</a>, a Rust-powered CLI and Lua library</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">🟠</td>
    </tr>
    <tr>
      <td align = "center">
          <a href="https://github.com/benlubas/molten-nvim">molten-nvim</a>
          <br/>
          <img src="https://img.shields.io/github/stars/benlubas/molten-nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/dccsillag/magma-nvim">magma-nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/dccsillag/magma-nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/kiyoon/jupynium.nvim">jupynium.nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/kiyoon/jupynium.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">JupyterLab via 🐍 (Selenium)</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/luk400/vim-jukit">vim-jukit</a>
        <br/>
        <img src="https://img.shields.io/github/stars/luk400/vim-jukit?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 autoload via vimscript</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/SUSTech-data/neopyter">neopyter</a>
        <br/>
        <img src="https://img.shields.io/github/stars/SUSTech-data/neopyter?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">JupyterLab via RPC</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/sheng-tse/jupynvim">jupynvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/sheng-tse/jupynvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">Custom Rust backend</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/lkhphuc/jupyter-kernel.nvim">jupyter-kernel.nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/lkhphuc/jupyter-kernel.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/matarina/pyrola.nvim">pyrola.nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/matarina/pyrola.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
    </tr>
    <tr>
      <td align = "center">
        <a href="https://github.com/sei40kr/jupyter.nvim">jupyter.nvim</a>
        <br/>
        <img src="https://img.shields.io/github/stars/sei40kr/jupyter.nvim?style=flat&label=%E2%AD%90" alt="stars">
      </td>
      <td align="left">🐍 remote plugin</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">❌</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
      <td align="center">✅</td>
    </tr>
  </tbody>
</table>

## FAQ

<details>
<summary>
For a 'Jupyter kernel supervisor' this plugin doesn't have much to do with
notebooks?
</summary>

> It's a common misconception that Jupyter == notebooks. Jupyter is really
> standard for how interactive languages can tell editors about execution
> results. It's somewhat analogous to LSP as a standard for how code analysis
> software can tell editors about code state.
> 
> If you want to implement the Jupyter standard for a language, you wrap the
> language in a Jupyter kernel. Ipykernel is a popular kernel for 🐍, Ark is
> another for R. There are many other kernels which exist for other languages.
> 
> Once you've got a kernel, your editor needs to implement a Jupyter client to
> talk to it. Most editors which implement a Jupyter client use it for some kind
> of notebook experience, but many also include some kind of REPL (notable
> examples are Positron and Jupyter's Qt Console).
> 
> Jet is a Jupyter client and kernel supervisor purpose-built for Neovim. So far
> jet.nvim only supports a REPL experience, but the infrastructure is there to
> support notebooks too, I just haven't implemented them on the Neovim side yet.
> But it's on the roadmap!
> 
> NB, one of the main benefits of a purpose-built client like Jet is that it will
> Neovim to tap into special/non-standard features that some kernels implement
> above and beyond the Jupyter spec. E.g. Ark adds a debugger, LSP server,
> variables pane, a dedicated help window, etc, all of which I'd like to expose
> in Neovim.

</details>
