"""Make a copied Hyprland config work on this computer.

- require("x") lines whose x.lua does not exist here are commented out (instead of breaking the config)
- values that newer Hyprland versions reject are clamped (shadow render_power 1..4)
Prints one line per change. Safe to run many times.
"""
import json
import os
import re
import sys

home = os.path.expanduser("~")
hypr = home + "/.config/hypr"
changes = []


def fix_requires(path):
    try:
        s = open(path).read()
    except OSError:
        return
    def repl(m):
        indent, name = m.group(1), m.group(2)
        base = os.path.join(hypr, *name.split("."))
        if os.path.exists(base + ".lua") or os.path.exists(os.path.join(base, "init.lua")):
            return m.group(0)
        changes.append("%s: module '%s' is not on this computer, turned it off" % (os.path.basename(path), name))
        return "%s-- [Phantom Shell] missing on this computer: %s" % (indent, m.group(0).strip())
    n = re.sub(r'^([ \t]*)require\(\s*"([^"]+)"\s*\)[^\n]*$', repl, s, flags=re.M)
    if n != s:
        open(path, "w").write(n)


def clamp_lua(path):
    try:
        s = open(path).read()
    except OSError:
        return
    def repl(m):
        v = int(m.group(2))
        nv = max(1, min(4, v))
        if nv != v:
            changes.append("%s: shadow render_power %d -> %d (allowed 1..4)" % (os.path.basename(path), v, nv))
        return m.group(1) + str(nv)
    n = re.sub(r'(render_power"?\]?\s*[=,:]\s*)(\d+)', repl, s)
    if n != s:
        open(path, "w").write(n)


def clamp_json(path):
    try:
        j = json.load(open(path))
    except Exception:
        return
    hit = False
    def walk(o):
        nonlocal hit
        if isinstance(o, dict):
            for k, v in o.items():
                if "render_power" in k and isinstance(v, (int, float)) and not 1 <= v <= 4:
                    o[k] = max(1, min(4, int(v)))
                    hit = True
                else:
                    walk(v)
    walk(j)
    if hit:
        json.dump(j, open(path, "w"))
        changes.append("%s: shadow render_power clamped to 1..4" % os.path.basename(path))


if os.path.isdir(hypr):
    for f in sorted(os.listdir(hypr)):
        if f.endswith(".lua"):
            clamp_lua(os.path.join(hypr, f))
    fix_requires(os.path.join(hypr, "hyprland.lua"))
clamp_json(home + "/.config/rice/hypr.json")

for c in changes:
    print(c)
if not changes:
    print("nothing to fix")
sys.exit(0)
