---
description: Safely push the current branch to its configured remote
argument-hint: "[remote, branch, or additional guidance]"
---
Safely push the current branch, using `$ARGUMENTS` as additional guidance.

Inspect the current branch, upstream, worktree status, and commits that have not been pushed.
Do not include or commit uncommitted changes automatically.
If the branch has no upstream, set the upstream only when the intended remote and branch are unambiguous.
Never force push unless explicitly requested, and prefer `--force-with-lease` over `--force` when force is required.
Push the intended commits and verify the resulting upstream status.
Report the remote, branch, commits pushed, and final status.
