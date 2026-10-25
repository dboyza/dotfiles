# Theme palette

`palette.json` is the single source of truth for the Rosé Pine Moon colors used across the dotfiles.
`deep` and `bright` are this repository's deeper default background and brighter default foreground; the rest follow Rosé Pine Moon, plus a few Neovim highlight shades.

WezTerm and Neovim read the file at startup.
Starship, tmux, and both floating-tab helpers cannot read JSON, so `scripts/sync-palette.py` regenerates their marked `generated palette` blocks.

After editing `palette.json`, run:

```sh
python3 scripts/sync-palette.py
```

`python3 scripts/sync-palette.py --check` fails when any generated block is out of date; the compatibility tests run it.
