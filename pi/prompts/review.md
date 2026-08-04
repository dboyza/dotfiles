---
description: Review current changes for correctness, regressions, and missing validation
argument-hint: "[scope or focus]"
---
Review the current repository changes without modifying them.
Inspect staged, unstaged, and relevant untracked files, using the repository instructions and `$ARGUMENTS` as additional focus.

Prioritize concrete findings involving correctness, security, regressions, portability, error handling, and missing tests.
Report findings first, ordered by severity, with precise file and line references.
Explain the impact and a practical fix for each finding.
If there are no findings, say so explicitly and mention any remaining validation gaps.
Do not praise the changes or provide a general summary before the findings.
