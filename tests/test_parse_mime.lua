local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local child = MiniTest.new_child_neovim()
local T = new_set({ hooks = { post_once = child.stop } })

T["Valid MIME types can be parsed"] = function()
	local parse = require("jet.core.utils.mime").parse
	local cases = {
		["text/plain"] = { type = "text", subtype = "plain", params = {} },
		["image/png"] = { type = "image", subtype = "png", params = {} },
		["text/plain.bla"] = { type = "text", subtype = "plain.bla", params = {} },
		["image/svg+xml"] = { type = "image", subtype = "svg", suffix = "xml", params = {} },
		["application/ld+json"] = { type = "application", subtype = "ld", suffix = "json", params = {} },
		["application/vnd.ms-excel"] = {
			type = "application",
			tree = "vnd",
			subtype = "ms-excel",
			params = {},
		},
		["application/vnd.oasis.opendocument.text"] = {
			type = "application",
			tree = "vnd",
			subtype = "oasis.opendocument.text",
			params = {},
		},
		["application/vnd.api+json"] = {
			type = "application",
			tree = "vnd",
			subtype = "api",
			suffix = "json",
			params = {},
		},
		["application/vnd.google-earth.kml+xml"] = {
			type = "application",
			tree = "vnd",
			subtype = "google-earth.kml",
			suffix = "xml",
			params = {},
		},
		["audio/prs.sid"] = { type = "audio", tree = "prs", subtype = "sid", params = {} },
		["application/x.custom-thing"] = {
			type = "application",
			tree = "x",
			subtype = "custom-thing",
			params = {},
		},
		["text/plain; charset=utf-8"] = {
			type = "text",
			subtype = "plain",
			params = { charset = "utf-8" },
		},
		["text/html; charset=UTF-8; boundary=xyz"] = {
			type = "text",
			subtype = "html",
			params = { charset = "utf-8", boundary = "xyz" },
		},
		['application/json; profile="https://example.com/schema"'] = {
			type = "application",
			subtype = "json",
			params = { profile = "https://example.com/schema" },
		},
		['text/plain; note="hello; world = ok"'] = {
			type = "text",
			subtype = "plain",
			params = { note = "hello; world = ok" },
		},
		["text/plain;charset=utf-8"] = {
			type = "text",
			subtype = "plain",
			params = { charset = "utf-8" },
		},
		["text/plain   ;   charset=utf-8   ;   format=flowed"] = {
			type = "text",
			subtype = "plain",
			params = { charset = "utf-8", format = "flowed" },
		},
		["TEXT/HTML; CHARSET=UTF-8"] = {
			type = "text",
			subtype = "html",
			params = { charset = "utf-8" },
		},
		["APPLICATION/VND.API+JSON"] = {
			type = "application",
			tree = "vnd",
			subtype = "api",
			suffix = "json",
			params = {},
		},
		['application/vnd.jupyter.widget-view+json; version="2.0"; encoding=utf-8'] = {
			type = "application",
			tree = "vnd",
			subtype = "jupyter.widget-view",
			suffix = "json",
			params = { version = "2.0", encoding = "utf-8" },
		},
		["application/x-tar"] = { type = "application", subtype = "x-tar", params = {} },
	}
	for mime_str, expected in pairs(cases) do
		local parsed = parse(mime_str)
		assert(parsed, "Failed to parse MIME type: " .. mime_str)
		assert(
			vim.deep_equal(parsed, expected),
			"Parsed result does not match expected for: "
				.. mime_str
				.. "\nExpected: "
				.. vim.inspect(expected)
				.. "\nActual: "
				.. vim.inspect(parsed)
		)
	end
end

T["Invalid MIME types fail to parse"] = function()
	local should_fail = {
		"",
		"text",
		"text/",
		"/plain",
		"text/plain;",
		"text/plain; =utf-8",
		"text/plain; charset=",
		"text plain",
		"text/plain extra",
		"text/plain; charset=utf 8",
	}

	for _, mime_str in ipairs(should_fail) do
		local parsed = require("jet.core.utils.mime").parse(mime_str, true)
		assert(parsed == nil, "Expected parsing to fail for: " .. mime_str)
	end
end

return T
