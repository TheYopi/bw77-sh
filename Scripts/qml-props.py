#!/usr/bin/env python3
"""
Flags properties assigned to a project component that the component does not
declare and does not inherit.

Run from the shell root, alongside qml-check.py:

    python3 Scripts/qml-props.py

This exists because of a specific failure. Four Control Center panes were
converted to use a new PaneGroup component, and the conversion carried a
`glitch: false` from the SectionHeader it replaced onto PaneGroup, which did
not declare it. Assigning an undeclared property is a LOAD error in QML, so all
four panes rendered as an empty rectangle - no warning visible in the UI, and
qml-check.py passed it happily, because the braces balance and the syntax is
perfectly valid. qmllint could not see it either: it cannot resolve the qs.*
directory modules that Quickshell handles its own way, so it has no idea what
PaneGroup declares.

Line-based scope tracking, so it is approximate - JS object literals and
inline animation blocks produce a handful of false positives. It is a thing to
read, not a gate to fail a build on. What it is good at is the case above: a
component being handed a property nobody gave it.
"""
import re, sys, glob, os

# Map component name -> (declared properties, base type) for every .qml in the tree.
comps = {}
for path in glob.glob("**/*.qml", recursive=True):
    if "/.git/" in path: continue
    name = os.path.basename(path)[:-4]
    src = open(path).read()
    body = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    body = re.sub(r'//[^\n]*', '', body)
    props = set(re.findall(r'\bproperty\s+(?:alias|var|int|real|bool|string|color|list<\w+>|\w+)\s+(\w+)\s*:', body))
    props |= set(re.findall(r'\breadonly\s+property\s+\w+\s+(\w+)\s*:', body))
    props |= set(re.findall(r'\bdefault\s+property\s+alias\s+(\w+)\s*:', body))
    props |= set(re.findall(r'\bsignal\s+(\w+)', body))
    m = re.search(r'^([A-Z]\w*)\s*\{', body, re.M)
    comps[name] = (props, m.group(1) if m else None)

# Anything on Item/QtObject, plus the common bases we do not model.
BUILTIN = {
 "Text": {"text","font","elide","wrapMode","color","horizontalAlignment",
          "verticalAlignment","lineHeight","maximumLineCount","textFormat",
          "renderType","style","styleColor","linkColor","fontSizeMode",
          "minimumPixelSize","minimumPointSize","truncated","contentWidth",
          "contentHeight","lineCount","advanceWidth","effectiveHorizontalAlignment"},
 "Rectangle": {"radius","gradient"},
 "Image": {"source","fillMode","sourceSize","asynchronous","cache","status","mipmap"},
 "MouseArea": {"hoverEnabled","cursorShape","acceptedButtons","containsMouse",
               "pressed","drag","propagateComposedEvents","preventStealing","scrollGestureEnabled"},
 "Flickable": {"contentWidth","contentHeight","contentX","contentY","boundsBehavior",
               "flickDeceleration","maximumFlickVelocity","interactive","visibleArea","contentItem"},
 "Column": set(), "Row": set(), "Grid": {"columns","rows","columnSpacing","rowSpacing",
               "horizontalItemAlignment","verticalItemAlignment","flow"},
 "Item": set(), "Loader": {"source","sourceComponent","active","asynchronous","item","status"},
 "Repeater": {"model","delegate","count"},
 "GridView": {"model","delegate","cellWidth","cellHeight","currentIndex","cacheBuffer"},
}

INHERITED = {
 "width","height","implicitWidth","implicitHeight","visible","opacity","enabled",
 "x","y","z","clip","rotation","scale","parent","focus","state","states","transitions",
 "transform","antialiasing","smooth","spacing","columns","rows","color","border",
 "anchors","children","data","layer","activeFocus","objectName","containmentMask",
 "baselineOffset","padding","topPadding","bottomPadding","leftPadding","rightPadding",
}

def resolve(name, seen=None):
    seen = seen or set()
    if name in seen or name not in comps: return set()
    seen.add(name)
    props, base = comps[name]
    out = props
    if base:
        out = out | BUILTIN.get(base, set()) | resolve(base, seen)
    return out

issues = 0
for path in glob.glob("**/*.qml", recursive=True):
    if "/.git/" in path: continue
    lines = open(path).read().split("\n")
    stack = []   # (component name or None, indent)
    for n, raw in enumerate(lines, 1):
        if not raw.strip() or raw.strip().startswith(("//","*","/*")): continue
        indent = len(raw) - len(raw.lstrip())
        while stack and indent <= stack[-1][1]: stack.pop()
        m = re.match(r'^\s*([A-Z]\w*)\s*\{\s*$', raw)
        if m:
            stack.append((m.group(1), indent)); continue
        if re.match(r'^\s*\w+\s*\{', raw):
            stack.append((None, indent)); continue
        pm = re.match(r'^\s*(\w+)\s*:', raw)
        if pm and stack and stack[-1][0] in comps:
            comp = stack[-1][0]
            prop = pm.group(1)
            if prop in INHERITED or prop == "id" or prop.startswith("on") or "." in prop:
                continue
            # Only meaningful when we can see the whole chain down to a base we model.
            root_base = comp
            chain = 0
            while root_base in comps and comps[root_base][1] in comps and chain < 10:
                root_base = comps[root_base][1]; chain += 1
            if comps.get(root_base, (None,None))[1] not in BUILTIN: continue
            known = resolve(comp)
            if prop not in known:
                print(f"{path}:{n}: '{prop}' assigned to {comp}, which does not declare it")
                issues += 1
print(f"\n{issues} suspicious assignment(s)")
sys.exit(1 if issues else 0)
