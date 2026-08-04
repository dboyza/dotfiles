---
description: Validate and commit the current repository changes
argument-hint: "[commit guidance]"
---
Inspect the current repository status and diff, using `$ARGUMENTS` as additional commit guidance.

Confirm that the changes form a coherent commit and do not include secrets, generated artifacts, or unrelated files.
Run the most relevant fast validation if it has not already been run.
Stage only the intended files and create one clear commit using the repository's existing commit style.
Never add an agent name, generated-by marker, or co-author attribution.
Do not amend an existing commit unless explicitly requested.
Do not push after committing.
Report the commit hash, subject, and validation performed.
