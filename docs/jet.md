# jet.nvim

jet.nvim is a Jupyter client/API for Neovim, built on top of the
[Jet](https://github.com/wurli/jet) CLI/Lua library.

## Configuration

Configure jet.nvim by passing options to `setup()`:

``` lua
require("jet").setup({
	-- Config options here
})
```

The full set of configuration options is as follows:

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Opts
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Ui.Opts
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Config.Img.Opts
```

```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Hooks
```

## UI

## Filetypes

## Extending jet.nvim


```{.sh include=true}
python3 scripts/emmylua-to-md.py --type jet.Kernel
```

