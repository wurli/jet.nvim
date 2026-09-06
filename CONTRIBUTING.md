# Contributing to jet.nvim

To develop jet.nvim you will need:

- `stylua`: <https://github.com/JohnnyMorganz/StyLua>
- `emmylua_ls` (and maybe `emmylua_check`): <https://github.com/emmyluals/emmylua-analyzer-rust>

All contributions need to pass `stylua --check .` and `emmylua_check .`, any
issues will cause CI to fail.

## Testing

Just run `make test`. This should:

- Install some testing kernels to `test-kernels/`
- Install mini.nvim to `deps/mini.nvim/` (for mini.test)
- Run the test suite

Tests also run in CI.

## Building the docs

Requires `emmylua_doc_cli`: <https://github.com/emmyluals/emmylua-analyzer-rust>.

Run `make docs` to:

* Install some special pandoc filters to `deps/`
* Export emmylua types to `emmylua_doc_cli/doc.json`
* Build the vimdoc files in `doc/`

Note: files in `doc/` are produced automatically; please edit the source
markdown in `docs/`.

There are CI checks in place to confirm that the `doc` dir is not stale.

