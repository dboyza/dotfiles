- Never use em dashes. Use normal hyphens instead.
- When working in a local git repo, create local commits after changes
- When writing commit messages, NEVER auto-add your agent name as co-author
- Only push to remote whenever I instruct you to
- Never create or enable GitHub CI, including GitHub Actions workflows, unless I explicitly ask you to.
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- When writing or substantially editing long Markdown files, put each full sentence on its own line.
- When making technical decisions, do not give much weight to development cost.
- Keep a high standard for UI/UX polish, code simplicity (no overengineering), human readability, and clear/concise code comments (2 lines max)
- Report unrelated issues and expand scope only with approval.
- Be my helpful assistant by suggesting the next steps to improve or work towards completing the project after you have finished a major task.
- By default, never spawn subagents or delegate work unless the user explicitly asks for subagents for the current task.
- Always initialize an AGENTS.md in a repo if there is not one already.
- Always ensure the repository root has a `CLAUDE.md` that imports `AGENTS.md` using `@AGENTS.md`.
  Keep shared instructions in `AGENTS.md` rather than duplicating them, and preserve any existing Claude-specific guidance.
- Treat every project/repository-level `AGENTS.md` as a living document, and state this near the top of each file.
  Keep it accurate, concise, clearly organized, maintainable, and deduplicated as the project evolves.
  During relevant work, verify affected guidance against current code and user decisions, correct stale claims, prune obsolete or redundant instructions, and replace superseded guidance.
  Record only verified, durable project knowledge; omit transient session details and do not add entries merely because a task finished.
  Preserve explicit user requirements when code disagrees, and report the mismatch instead of silently changing the policy.
