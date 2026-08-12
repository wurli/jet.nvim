"""Convert emmylua-doc-cli's doc.json into Markdown."""

from __future__ import annotations

import argparse
import json
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


# ---------- Members (of modules and classes) ----------


@dataclass
class Base:
    """Fields shared by every documented item."""

    name: str
    description: str | None
    visibility: str | None
    deprecated: bool
    deprecation_reason: str | None
    tag_content: Any  # varies; keep raw


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


def _common(d: dict) -> dict:
    return {
        "name": d["name"],
        "description": d.get("description"),
        "visibility": d.get("visibility"),
        "deprecated": d.get("deprecated", False),
        "deprecation_reason": d.get("deprecation_reason"),
        "tag_content": d.get("tag_content"),
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


# ---------- Render ---------------------------


def _render_fn(x: Fn, parent=None):
    name = x.name if parent is None else f"{parent}:{x.name}"
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
    )


def _render_class(x: Class):
    fields = [
        [
            f"{{{field.name}}}",
            f": (`{field.typ or 'any'}`)",
            *(
                []
                if field.description is None or field.description == ""
                else ["  " + line for line in field.description.split("\n")] + [""]
            ),
            "",
        ]
        for field in x.members
        if type(field) is Field and field.visibility != "private"
    ]
    field_lines = [line for f in fields for line in f]

    method_lines = [
        _render_fn(member, x.name.split(".")[-1])
        for member in x.members
        if type(member) is Fn and member.visibility != "private"
    ]

    return (
        ["#### " + x.name]
        + [""]
        + (x.description or "").split("\n")
        + [""]
        + ([] if len(field_lines) == 0 else ["###### Fields:", "", *field_lines])
        + [line for block in method_lines for line in block]
    )


# ---------- Entry point ----------


def main() -> int:
    """Render a single class from emmylua_doc_cli/doc.json as Markdown to stdout."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--type", help="Type to render", required=True)
    args = parser.parse_args()

    selected_type = args.type

    with open("emmylua_doc_cli/doc.json") as f:
        raw = json.load(f)

    doc = parse(raw)

    for emmylua_type in doc.types:
        if type(emmylua_type) is Class and emmylua_type.name == selected_type:
            print("\n".join(_render_class(emmylua_type)))
            return 0

    print("Type not found")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
