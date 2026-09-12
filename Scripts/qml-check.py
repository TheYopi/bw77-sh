#!/usr/bin/env python3
"""
Structural checks for the shell's QML, for the two mistakes that are easy to
make in bulk edits and that qmllint does not report usefully.

    Scripts/qml-check.py [root]

1. Brace balance.

   A stray or missing brace can still parse as valid QML - the file just means
   something different from what was intended, usually attaching the rest of the
   file to the wrong object. qmllint reported a file with an orphaned closing
   brace as clean.

2. The same property or handler assigned twice on one object.

   QML rejects this at load with "Property value set multiple times" - it does
   not treat the second as an override. It is easy to do when a handler is added
   to an object that already had one further down the file, which is how a
   second Component.onCompleted got into OsdLayer.

3. Calls to a function on the file's own root that does not exist.

   A ReferenceError inside a QML signal handler is a warning on stderr, not a
   failure - the handler stops and everything else carries on. `persist()` was
   deleted from DesktopWidgetProxy by an edit to the block above it and nothing
   noticed for several builds; every drag and resize silently did nothing.

4. Properties assigned to wrapper components that do not have them.

   Several components in Common/ are Items wrapping a Text or a Rectangle. None
   of the wrapped type's properties exist on the wrapper unless explicitly
   re-declared and forwarded, so `horizontalAlignment` on a GlitchText fails at
   load with "cannot assign to non-existent property" - and it fails at load,
   which takes the whole shell down rather than one widget.

   CyberText is deliberately not checked: it derives from Text, so every Text
   property is legitimate on it.

Exits non-zero if anything is found, so it can gate a reload.
"""

import pathlib
import re
import sys

# Properties any Item-derived component accepts.
ITEM_PROPS = set("""
x y z width height implicitWidth implicitHeight anchors visible opacity clip
scale rotation transform enabled focus activeFocus parent data children states
transitions layer antialiasing smooth objectName id Component Keys Drag Layout
""".split())

WRAPPERS = [
    "GlitchText", "StepArrow", "CyberToggle", "CyberToggleRow", "CyberSelector",
    "CyberSlider", "CyberDropdown", "FontField", "KeyChip", "SegmentBar",
    "NotchRect", "CyberButton",
]


def brace_balance(text):
    """Net brace depth, ignoring comments and all three string forms.

    Template literals matter: `${a}` is balanced on its own, but a backtick
    string containing a lone brace is not, and treating backticks as ordinary
    characters produced false positives on two files.
    """
    depth = 0
    i = 0
    n = len(text)

    while i < n:
        c = text[i]

        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue

        if c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue

        if c in "\"'`":
            quote = c
            i += 1
            while i < n and text[i] != quote:
                if text[i] == "\\":
                    i += 1
                i += 1
            i += 1
            continue

        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1

    return depth


# A scope opened by an object declaration rather than by a function or a
# handler body. Object types are capitalised, optionally qualified, and may carry
# an `on <property>` clause for property-value sources.
OBJECT_OPEN = re.compile(r"^(\s*)[A-Z][\w.]*(\s+on\s+\w+)?\s*\{\s*$")

# `name:` or `name.sub:` at the start of a line, which is how every property
# assignment and signal handler is written in this codebase.
ASSIGN = re.compile(r"^(\s*)([\w.]+)\s*:")


def duplicate_assignments(text):
    """Property names assigned more than once within the same object body.

    Grouped by indentation under the object that opened them: anything deeper
    belongs to a nested object, and anything inside a function or handler body
    is skipped because those open with a lowercase name and never match
    OBJECT_OPEN.
    """
    found = []
    stack = []          # (indent_of_children, {name: first_line})

    for i, line in enumerate(text.split("\n")):
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("*"):
            continue

        m = OBJECT_OPEN.match(line)
        if m:
            stack.append((len(m.group(1)) + 4, {}))
            continue

        if stack:
            child_indent = stack[-1][0]
            indent = len(line) - len(line.lstrip())

            if stripped in ("}", "},") and indent < child_indent:
                stack.pop()
                continue

            am = ASSIGN.match(line)
            if am and len(am.group(1)) == child_indent:
                name = am.group(2)
                # Grouped properties are written both ways - `anchors.fill` and
                # an `anchors { }` block - and repeating a group prefix with
                # different suffixes is legal.
                if "." in name and not name.startswith("Component."):
                    continue
                seen = stack[-1][1]
                if name in seen:
                    found.append((i + 1, name, seen[name]))
                else:
                    seen[name] = i + 1

    return found


ROOT_ID = re.compile(r"^\s*id:\s*(\w+)\s*$", re.M)
ROOT_TYPE = re.compile(r"^([A-Z][\w.]*)\s*\{\s*$", re.M)


def own_members(text):
    members = set(re.findall(r"^\s*function\s+(\w+)", text, re.M))
    members |= set(re.findall(r"^\s*(?:readonly\s+)?property\s+\S+\s+(\w+)", text, re.M))
    members |= set(re.findall(r"^\s*(?:default\s+)?property\s+alias\s+(\w+)", text, re.M))
    members |= set(re.findall(r"^\s*signal\s+(\w+)", text, re.M))
    return members


def inherited_members(text, index, depth=0):
    """Members of the component this file derives from.

    A widget declared as `BarItem { ... }` inherits cfgColor() from
    BarItem.qml, and without following that every such call reads as missing.
    Only project-local base types can be followed - anything from Quickshell or
    QtQuick is not on disk here, which is why unknown types simply widen the
    accepted set rather than narrowing it.
    """
    if depth > 3:
        return set(), False

    m = ROOT_TYPE.search(text)
    if not m:
        return set(), True

    name = m.group(1)

    base = index.get(name)
    if base is None:
        # Not a project component. Framework types whose surface we know are
        # fine to check against; anything else - a Quickshell service type, an
        # imported module - could provide the member, so the file is skipped
        # rather than guessed at.
        return set(), name in KNOWN_BASES

    base_text = base.read_text()
    up, resolved = inherited_members(base_text, index, depth + 1)
    return own_members(base_text) | up, resolved


def missing_root_calls(text, index):
    """Calls to `<rootId>.name(` where the root declares no such member.

    Only the outermost id is checked, and only members it could plausibly own -
    a false positive here would be worse than a miss, so anything the file also
    declares as a property, signal or alias is accepted.
    """
    ids = ROOT_ID.findall(text)
    if not ids:
        return []
    root_id = ids[0]

    members = own_members(text)

    up, resolved = inherited_members(text, index)
    if not resolved:
        return []
    members |= up

    found = []
    seen = set()
    pattern = re.compile(r"\b" + re.escape(root_id) + r"\.(\w+)\s*\(")

    for i, line in enumerate(text.split("\n")):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("*"):
            continue
        for name in pattern.findall(line):
            if name in members or name in seen:
                continue
            # Anything Item itself provides, called on the root.
            if name in ITEM_METHODS:
                continue
            seen.add(name)
            found.append((i + 1, f"{root_id}.{name}()"))
    return found


# Framework base types this codebase derives from whose members are covered by
# ITEM_METHODS. A root of one of these can be checked; a root of anything else
# unknown cannot, because the missing name might come from the base.
KNOWN_BASES = set("""
Item Rectangle MouseArea Text Column Row Grid Flow Flickable Canvas Shape
QtObject Scope Singleton Variants PanelWindow Window Loader Repeater
""".split())


# Methods every Item has, which a root can legitimately be asked for.
ITEM_METHODS = set("""
mapToItem mapFromItem mapToGlobal mapFromGlobal childAt contains forceActiveFocus
nextItemInFocusChain grabToImage update destroy toString restart start stop
""".split())


def declared_props(path):
    """Everything a component declares, plus the handlers those imply."""
    text = path.read_text()
    props = set(re.findall(r"^\s*(?:readonly\s+)?property\s+\S+\s+(\w+)", text, re.M))
    props |= set(re.findall(r"^\s*(?:default\s+)?property\s+alias\s+(\w+)", text, re.M))
    props |= set(re.findall(r"^\s*signal\s+(\w+)", text, re.M))
    props |= set(re.findall(r"^\s*function\s+(\w+)", text, re.M))

    handlers = set()
    for p in props:
        cap = "on" + p[0].upper() + p[1:]
        handlers.add(cap)
        handlers.add(cap + "Changed")
    return props | handlers


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    files = sorted(root.rglob("*.qml"))
    problems = 0

    # Type name -> file, for resolving what a component inherits.
    type_index = {f.stem: f for f in files}

    allowed = {}
    for name in WRAPPERS:
        path = root / "Common" / f"{name}.qml"
        if path.exists():
            allowed[name] = declared_props(path) | ITEM_PROPS

    pattern = re.compile(r"\b(" + "|".join(allowed) + r")\s*\{\s*$") if allowed else None

    for f in files:
        text = f.read_text()

        depth = brace_balance(text)
        if depth != 0:
            print(f"{f}: brace balance {depth:+d}")
            problems += 1

        for line_no, call in missing_root_calls(text, type_index):
            print(f"{f}:{line_no}: {call} is not declared in this file")
            problems += 1

        for line_no, name, first in duplicate_assignments(text):
            print(f"{f}:{line_no}: '{name}' already set at line {first}")
            problems += 1

        if not pattern:
            continue

        # Only direct children of a wrapper are checked - one indent level in.
        # Anything deeper belongs to some other object nested inside it.
        stack = []
        for i, line in enumerate(text.split("\n")):
            m = pattern.search(line)
            if m:
                stack.append((m.group(1), line.index(m.group(1))))
                continue
            if not stack:
                continue

            name, col = stack[-1]
            indent = len(line) - len(line.lstrip())
            if line.strip() in ("}", "},") and indent <= col:
                stack.pop()
                continue

            am = re.match(r"^(\s*)(\w+)(\.\w+)?\s*:", line)
            if am and len(am.group(1)) == col + 4 and not am.group(3):
                prop = am.group(2)
                if prop not in allowed[name]:
                    print(f"{f}:{i + 1}: {name} has no property '{prop}'")
                    problems += 1

    print(f"\n{len(files)} files checked, {problems} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
