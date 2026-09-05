"""Convert emmylua-doc-cli's doc.json into Markdown."""

from __future__ import annotations

import argparse
import json
from collections import OrderedDict
from dataclasses import dataclass, field
from typing import Any

# ---------- Leaf shapes ----------


@dataclass
class Loc:
    file: str
    line: int


@dataclass
class Param:
    name: str | None
    typ: str | None
    desc: str | None


@dataclass
class Return:
    name: str | None
    typ: str | None
    desc: str | None


@dataclass
class Generic:
    name: str
    base: str | None


@dataclass
class Tag:
    tag_name: str
    content: str


# ---------- Members (of modules and classes) ----------


@dataclass
class Base:
    """Fields shared by every documented item."""

    name: str
    description: str | None
    visibility: str | None
    deprecated: bool
    deprecation_reason: str | None
    tag_content: list[Tag] | None


@dataclass
class Field(Base):
    loc: Loc
    typ: str | None
    literal: Any | None
    type: str = "field"


@dataclass
class Fn(Base):
    loc: Loc
    generics: list[Generic]
    params: list[Param]
    returns: list[Return]
    overloads: list[Any]
    is_async: bool
    is_meth: bool
    is_nodiscard: bool
    nodiscard_message: str | None
    type: str = "fn"


Member = Field | Fn


# ---------- Top-level containers ----------


@dataclass
class Module(Base):
    file: str
    typ: str | None
    members: list[Member]
    namespace: str | None
    using: list[Any]


@dataclass
class Class(Base):
    loc: list[Loc]
    bases: list[str]
    generics: list[Generic]
    members: list[Member]
    type: str = "class"


@dataclass
class Alias(Base):
    loc: list[Loc]
    typ: str | None
    generics: list[Generic]
    members: list[Member]
    type: str = "alias"


Type = Class | Alias


@dataclass
class Doc:
    modules: list[Module]
    types: list[Type]
    globals: list[Field]
    config: dict = field(default_factory=dict)


# ---------- Parsing ----------


def _tags(d: dict | None) -> list[Tag] | None:
    if d is None:
        return None
    return [Tag(tag_name=t["tag_name"], content=t["content"]) for t in d]


def _common(d: dict) -> dict:
    return {
        "name": d["name"],
        "description": d.get("description"),
        "visibility": d.get("visibility"),
        "deprecated": d.get("deprecated", False),
        "deprecation_reason": d.get("deprecation_reason"),
        "tag_content": _tags(d.get("tag_content")),
    }


def _loc(d: dict) -> Loc:
    return Loc(file=d["file"], line=d["line"])


def _field(d: dict) -> Field:
    return Field(
        **_common(d),
        loc=_loc(d["loc"]),
        typ=d.get("typ"),
        literal=d.get("literal"),
    )


def _member(d: dict) -> Member:
    if d["type"] == "fn":
        return Fn(
            **_common(d),
            loc=_loc(d["loc"]),
            generics=[Generic(**g) for g in d["generics"]],
            params=[Param(**p) for p in d["params"]],
            returns=[Return(**r) for r in d["returns"]],
            overloads=d["overloads"],
            is_async=d["is_async"],
            is_meth=d["is_meth"],
            is_nodiscard=d["is_nodiscard"],
            nodiscard_message=d.get("nodiscard_message"),
        )
    if d["type"] == "field":
        return _field(d)
    raise ValueError(f"unknown member type: {d['type']!r}")


def _module(d: dict) -> Module:
    return Module(
        **_common(d),
        file=d["file"],
        typ=d.get("typ"),
        members=[_member(m) for m in d["members"]],
        namespace=d.get("namespace"),
        using=d.get("using", []),
    )


def _type(d: dict) -> Type:
    if d["type"] == "class":
        return Class(
            **_common(d),
            loc=[_loc(x) for x in d["loc"]],
            bases=d["bases"],
            generics=[Generic(**g) for g in d["generics"]],
            members=[_member(m) for m in d["members"]],
        )
    if d["type"] == "alias":
        return Alias(
            **_common(d),
            loc=[_loc(x) for x in d["loc"]],
            typ=d.get("typ"),
            generics=[Generic(**g) for g in d["generics"]],
            members=[_member(m) for m in d["members"]],
        )
    raise ValueError(f"unknown top-level type: {d['type']!r}")


def parse(raw: dict) -> Doc:
    return Doc(
        modules=[_module(m) for m in raw["modules"]],
        types=[_type(t) for t in raw["types"]],
        globals=[_field(g) for g in raw["globals"]],
    )


# ---------- Find stuff in the Doc ---------------------------


def _get_type(doc: Doc, t: str) -> Class | None:
    for emmylua_type in doc.types:
        if type(emmylua_type) is Class and emmylua_type.name == t:
            return emmylua_type


def _get_mod(doc: Doc, m: str) -> Module | None:
    for emmylua_mod in doc.modules:
        if type(emmylua_mod) is Module and emmylua_mod.name == m:
            return emmylua_mod


# ---------- Render ---------------------------


def _render_tags(tags: list[Tag] | None) -> list[str]:
    grouped: dict[str, list[str]] = OrderedDict()

    for tag in tags or []:
        name = tag.tag_name.capitalize()
        grouped[name] = grouped.get(name, [])
        grouped[name].append(tag.content)

    tag_blocks = [
        [
            f"###### {tag_name}:",
            "",
            *[f"- {line}" for line in tag_lines],
            "",
        ]
        for tag_name, tag_lines in grouped.items()
    ]

    return [line for block in tag_blocks for line in block]


def _render_fn(doc: Doc, x: Fn, parent=None):
    sep = ":" if x.is_meth else "."
    name = x.name if parent is None else f"{parent}{sep}{x.name}"
    params = ", ".join([f"{{{param.name}}}" for param in x.params])
    title_line = f"##### {name}({params}){{#{name}()}}"

    desc_lines = (
        []
        if x.description is None or x.description == ""
        else ["  " + line for line in x.description.split("\n")] + [""]
    )

    params = [
        [
            f"{{{param.name}}}",
            f": (`{param.typ or 'any'}`)",
            *([] if param.desc is None else [param.desc]),
            *_render_opts_fields(doc, param.typ),
            "",
        ]
        for param in x.params
    ]
    param_lines = [line for p in params for line in p]

    return_lines = [
        f"(`{val.typ or ''}`) {val.desc or ''}\\"
        for val in x.returns
        if val.typ != "nil"
    ]

    return (
        [title_line]
        + [""]
        + desc_lines
        + (
            []
            if len(param_lines) == 0
            else ["###### Parameters:", "::: {#args}", *param_lines, ":::"]
        )
        + (
            []
            if len(return_lines) == 0
            else ["", "###### Return:", "::: {#args}", *return_lines, ":::"]
        )
        + [""]
        + _render_tags(x.tag_content)
    )


def _render_opts_fields(doc: Doc, which: str | None, indent=2) -> list[str]:
    if which is not None and which.endswith("?"):
        which = which[0:-1]

    if which is None or not which.endswith("Opts") or indent > 8:
        return []

    x = _get_type(doc, which)
    if x is None or x.visibility == "private":
        return []

    ind = " " * indent

    def render_one(item: Field | Fn) -> list[str]:
        if type(item) is Field:
            return [
                f"{ind}* {item.name} (`{item.typ}`)"
                + ("" if item.description is None else f": {item.description}"),
                *_render_opts_fields(doc, item.typ, indent + 2),
            ]
        elif type(item) is Fn:
            return [f"{ind}* {item.name} (function): {item.description}"]
        else:
            raise ValueError("Value is not a Field or Fn")

    fields = [line for f in x.members for line in render_one(f)]
    return ["", *fields]


def _render_class(x: Class | Module, doc: Doc):
    fields = [
        [
            f"{{{field.name}}}",
            f": (`{field.typ or 'any'}`)",
            *(
                []
                if field.description is None or field.description == ""
                else ["  " + line for line in field.description.split("\n")] + [""]
            ),
            *_render_opts_fields(doc, field.typ),
            "",
        ]
        for field in x.members
        if type(field) is Field and field.visibility != "private"
    ]
    field_lines = [line for f in fields for line in f]

    method_lines = [
        _render_fn(doc, member, x.name.split(".")[-1])
        for member in x.members
        if type(member) is Fn and member.visibility != "private"
    ]

    header = ["#### " + x.name] if type(x) is Class else []

    if type(x) is Module and not x.description:
        x.description = "\n".join(
            [
                "``` lua",
                "-- Access the module from Lua",
                f'local {x.name.split(".")[-1]} = require("{x.name}")',
                "```",
            ]
        )

    return (
        header
        + [""]
        + (x.description or "").split("\n")
        + [""]
        + ([] if len(field_lines) == 0 else ["###### Fields:", "", *field_lines])
        + _render_tags(x.tag_content)
        + [line for block in method_lines for line in block]
    )


# ---------- Entry point ----------


def main() -> int:
    """Render a single class from emmylua_doc_cli/doc.json as Markdown to stdout."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--type", help="Type to render", required=False)
    parser.add_argument("--mod", help="Module to render", required=False)
    args = parser.parse_args()

    with open("emmylua_doc_cli/doc.json") as f:
        raw = json.load(f)

    doc = parse(raw)

    if args.type:
        emmylua_type = _get_type(doc, args.type)
        if emmylua_type is not None:
            print("\n".join(_render_class(emmylua_type, doc)))
            return 0

    if args.mod:
        emmylua_mod = _get_mod(doc, args.mod)
        if emmylua_mod is not None:
            print("\n".join(_render_class(emmylua_mod, doc)))
            return 0

    print("No emmylua docs found")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
