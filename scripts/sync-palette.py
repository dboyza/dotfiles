#!/usr/bin/env python3
"""Regenerate the palette blocks that cannot read theme/palette.json at runtime."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PALETTE = json.loads((ROOT / "theme" / "palette.json").read_text())
HEX = re.compile(r"^#[0-9a-f]{6}$")
for name, value in PALETTE.items():
    if not HEX.match(value):
        sys.exit(f"palette.json: {name} must be a lowercase #rrggbb color")


def rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def pascal(name):
    return "".join(part.capitalize() for part in name.split("_"))


# Section: Generators, one per consumer file

def starship():
    lines = ["[palettes.rose_pine_moon]"] + [f'{name} = "{value}"' for name, value in PALETTE.items()]
    return "\n".join(lines)


def tmux():
    # Format strings expand @pal_* options; colour and style options do not, so they get literal values.
    p = PALETTE
    options = [
        f'set -g status-style "bg=default,fg={p["subtle"]}"',
        f'set -g pane-border-style "fg={p["muted"]}"',
        f'set -g pane-active-border-style "fg={p["gold"]}"',
        f'set -g display-panes-colour "{p["love"]}"',
        f'set -g display-panes-active-colour "{p["gold"]}"',
        f'set -g message-style "bg={p["gold"]},fg={p["deep"]}"',
        f'set -g mode-style "bg={p["blush"]},fg={p["deep"]}"',
    ]
    return "\n".join([f'set -g @pal_{name} "{value}"' for name, value in p.items()] + options)


def swift():
    out = ["enum Palette {"]
    for name, value in PALETTE.items():
        r, g, b = rgb(value)
        out.append(f"    static let {name} = NSColor(srgbRed: {r}/255, green: {g}/255, blue: {b}/255, alpha: 1)")
    out.append("}")
    return "\n".join(out)


def csharp():
    out = ["internal static class Palette {"]
    for name, value in PALETTE.items():
        r, g, b = rgb(value)
        out.append(f"    internal static readonly Color {pascal(name)} = Color.FromArgb({r}, {g}, {b});")
    # COLORREF is 0x00BBGGRR, not RGB.
    for label, name in (("FrameFocused", "subtle"), ("FrameUnfocused", "overlay")):
        r, g, b = rgb(PALETTE[name])
        out.append(f"    internal const int {label} = 0x{b:02X}{g:02X}{r:02X};")
    out.append("}")
    return "\n".join(out)


# (file, comment prefix, generator)
TARGETS = [
    ("starship/starship.toml", "#", starship),
    ("tmux/.tmux.conf", "#", tmux),
    ("wezterm/floating-tabs/main.swift", "//", swift),
    ("wezterm/floating-tabs/windows.cs", "//", csharp),
]


def render(path, comment, generator):
    text = path.read_text()
    begin = f"{comment} BEGIN generated palette (edit theme/palette.json, then run scripts/sync-palette.py)"
    end = f"{comment} END generated palette"
    pattern = re.compile(re.escape(f"{comment} BEGIN generated palette") + r"[^\n]*\n(?:.*?\n)?" + re.escape(end), re.S)
    if not pattern.search(text):
        sys.exit(f"{path}: missing generated palette markers")
    return pattern.sub(lambda _: f"{begin}\n{generator()}\n{end}", text, count=1)


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for relative, comment, generator in TARGETS:
        path = ROOT / relative
        updated = render(path, comment, generator)
        if updated != path.read_text():
            stale.append(relative)
            if not check:
                path.write_text(updated)
    if check and stale:
        sys.exit("generated palette blocks are stale: " + ", ".join(stale) + " (run scripts/sync-palette.py)")
    print("palette blocks are current" if check or not stale else "updated: " + ", ".join(stale))


main()
