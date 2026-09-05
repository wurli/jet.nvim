---
title: jet.nvim
filename: jet.txt
vimdoc-prefix: jet
---

jet.nvim is a Jupyter client/API for Neovim, built on top of the
Jet CLI/Lua library (https://github.com/wurli/jet).

# Configuration

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

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Kernel
```

# UI

## Kernel management

`:Jet` without args brings up a UI for kernel management. This allows:

* Renaming sessions (sets the `Kernel.session_name` attribute)
* Stopping or starting kernels
* Connecting to kernels managed by Jet which are not owned by the current
  Neovim session
* Execution information (hit <Enter> over a running kernel to expand
  information)

## The repl buffer

The Jet repl buffer is just `jet start` (or `jet attach`) running in neovim's
built-in terminal.

`vim.b.jet.session_id` is set to the kernel's `session_id`

## Image display

When a connected kernel produces an image, jet.nvim saves the image to the
kernel's image directory (see |jet-Kernel:img_dir()|). The kernel image buffer
cycles through these saved images.

Image display works best when powered by snacks.nvim
(https://github.com/folke/snacks.nvim), but there is also basic support for
image.nvim (https://github.com/3rd/image.nvim). In the future jet.nvim will
migrate to Neovim's native image API.

You can open a kernel's image buffer using `Kernel:img_open()`

## Filetypes

jet.nvim tries to determine the filetype of each running kernel, but may
occasionally fail to do so, or might guess the wrong filetype. In such cases you
can set the kernel filetype manually using hooks:

``` lua
-- Woxi is a jupyter kernel for the wolfram language: https://github.com/ad-si/Woxi
local hooks = require("jet.core.config").options.hooks
hooks.on_kernel_init.set_woxi_filetype = function(k)
	if k.display_name:match("woxi") then
		k.filetype = "mma"
	end
end
```

## AI integration

AI agents can interact with your Jet session. To enable this:
1. Make sure the `jet` CLI is on the `PATH`
2. Install the jet skill (run `:!jet skill` to view the full skill text)

## Concepts

### Sessions

A Jet "session" is a running kernel, which can be connected to by multiple
clients. Jet assigns each session an unique `session_id` comprised of four
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

## The API module{#jet.api}

```{.sh include=true}
python3 scripts/emmylua-to-md.py --mod jet.api
```

# Extending jet.nvim

jet.nvim aims to delegate 

#### jet.filetype
