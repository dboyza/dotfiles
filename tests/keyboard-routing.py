#!/usr/bin/env python3
"""Exercise real terminal input through an isolated tmux client into Neovim."""

import json
import os
from pathlib import Path
import select
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

# Native Windows has no tmux or Unix PTYs; mocked WezTerm and Neovim tests cover it.
if os.name == "nt" or not all(shutil.which(tool) for tool in ("tmux", "nvim")):
    print("Keyboard PTY integration skipped: requires Unix, tmux, and Neovim")
    sys.exit(78)

import pty
import fcntl
import struct
import termios

REPO = Path(__file__).resolve().parents[1]

# Section: Isolated tmux and editor setup
with tempfile.TemporaryDirectory(prefix="dotfiles-keys-", dir="/tmp") as temporary:
    root = Path(temporary)
    env = dict(os.environ, HOME=temporary, TERM="xterm-256color",
               DOTFILES_NVIM_CORE_ONLY="1", XDG_STATE_HOME=temporary + "/state",
               XDG_CACHE_HOME=temporary + "/cache", XDG_DATA_HOME=temporary + "/data")
    for name in ("TMUX", "HERDR_ENV", "HERDR_PANE_ID", "HERDR_SOCKET_PATH"):
        env.pop(name, None)
    # Avoid restoration hooks and user-session state; plugins have their own tests.
    for directory, entrypoint in (("tmux-resurrect", "resurrect"),
                                  ("tmux-assistant-resurrect", "tmux-assistant-resurrect"),
                                  ("tmux-continuum", "continuum")):
        script = root / ".tmux/plugins" / directory / (entrypoint + ".tmux")
        script.parent.mkdir(parents=True)
        script.write_text("#!/bin/sh\nexit 0\n")
        script.chmod(0o755)
    base = ["tmux", "-S", str(root / "tmux.sock")]
    rpc = str(root / "nvim.sock")

    def tmux(*arguments):
        return subprocess.check_output(base + list(arguments), env=env, text=True,
                                       timeout=10).strip()

    def evaluate(expression):
        return subprocess.check_output(["nvim", "--server", rpc, "--remote-expr", expression],
                                       env=env, text=True, timeout=5).strip()

    init = root / "init.lua"
    project = root / "project with spaces"
    (project / ".git").mkdir(parents=True)
    source = project / "src" / "example.txt"
    source.parent.mkdir()
    init.write_text("dofile(" + json.dumps(str(REPO / "nvim/init.lua")) + "); "
                    "vim.opt.clipboard = ''; local lines = {}; "
                    "for i=1,300 do lines[i]='line '..i end; "
                    "vim.api.nvim_buf_set_name(0," + json.dumps(str(source)) + "); "
                    "vim.api.nvim_buf_set_lines(0,0,-1,false,lines); "
                    # Exercise the tracked Git mapping while mocking only the plugin boundary.
                    "package.loaded.neogit = { open = function(opts) vim.g.neogit_cwd = opts.cwd end }; "
                    "for _, spec in ipairs(dofile(" + json.dumps(str(REPO / "nvim/lua/plugins/git.lua")) + ")) do "
                    "if spec[1] == 'NeogitOrg/neogit' then for _, key in ipairs(spec.keys) do "
                    "vim.keymap.set('n', key[1], key[2]) end end end; "
                    "vim.keymap.set('n','<C-PageDown>',function() vim.g.page='down' end); "
                    "vim.keymap.set('n','<C-PageUp>',function() vim.g.page='up' end)")
    tmux("-f", str(REPO / "tmux/.tmux.conf"), "new-session", "-d", "-s", "keys",
         "-x", "100", "-y", "30", shlex.join(["nvim", "-i", "NONE", "-u", str(init), "--listen", rpc]))
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
    client = subprocess.Popen(base + ["attach-session", "-t", "keys"], env=env,
                              stdin=slave, stdout=slave, stderr=slave)
    os.close(slave)

    # Section: PTY input and bounded observation
    def until(predicate, message):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.05)[0]:
                os.read(master, 65536)
            if predicate():
                return
        raise AssertionError(message)

    def send(keys):
        os.write(master, keys)

    # Section: End-to-end navigation assertions
    try:
        until(lambda: Path(rpc).exists() and tmux("list-clients") != "", "client did not attach")
        until(lambda: tmux("display-message", "-p", "#{alternate_on}") == "1", "Neovim did not start")
        send(b" gg")
        until(lambda: Path(evaluate("get(g:, 'neogit_cwd', '')")).resolve() == project.resolve(),
              "Space gg must reach the file's project through tmux, preserving spaces")
        send(b"\x1b[6~")
        until(lambda: int(evaluate("line('.')")) > 1, "PageDown did not reach Neovim")
        assert tmux("display-message", "-p", "#{pane_in_mode}") == "0"
        page_down_line = int(evaluate("line('.')"))
        send(b"\x1b[5~")
        until(lambda: int(evaluate("line('.')")) < page_down_line, "PageUp did not reach Neovim")
        for sequence, expected in ((b"\x1b[6;5~", "down"), (b"\x1b[5;5~", "up")):
            send(sequence)
            until(lambda: evaluate("get(g:, 'page', '')") == expected, "Control+Page key was intercepted")
        evaluate('luaeval("vim.api.nvim_win_set_cursor(0, {1, 0})")')
        # WezTerm translates Option+Right to this portable sequence.
        send(b"i\x1b[1;5CX\x1b")
        until(lambda: evaluate("getline(1)") == "line X1", "Option/Control word movement failed in Insert mode")
        until(lambda: evaluate("mode()") == "n", "Neovim did not leave Insert mode")
        editor = tmux("display-message", "-p", "#{pane_id}")
        send(b"\x07\\")
        until(lambda: len(tmux("list-panes").splitlines()) == 2, "prefix+backslash did not split")
        shell = tmux("display-message", "-p", "#{pane_id}")
        send(b"\x07h")
        until(lambda: tmux("display-message", "-p", "#{pane_id}") == editor, "prefix+h did not focus left")
        # Exit repeat mode before sending another prefix.
        tmux("switch-client", "-T", "root")
        send(b"\x07l")
        until(lambda: tmux("display-message", "-p", "#{pane_id}") == shell, "prefix+l did not focus right")
        tmux("switch-client", "-T", "root")
        width = int(tmux("display-message", "-p", "#{pane_width}"))
        send(b"\x07H")
        until(lambda: int(tmux("display-message", "-p", "#{pane_width}")) != width, "prefix+H did not resize")
        tmux("switch-client", "-T", "root")
        send(b"\x1b[5~")
        until(lambda: tmux("display-message", "-p", "#{pane_in_mode}") == "1", "shell PageUp must enter scrollback")
        print("Keyboard PTY integration passed: project Git shortcut, application pages, word motion, "
              "pane focus/resize, shell scrollback")
    finally:
        subprocess.run(base + ["kill-server"], env=env, capture_output=True, timeout=5)
        os.close(master)
        try:
            client.wait(timeout=5)
        except subprocess.TimeoutExpired:
            client.kill()
            client.wait(timeout=5)
