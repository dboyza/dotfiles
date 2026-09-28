# agent instructions

- Never use em dashes. Use normal hyphens instead.
- When working in a local git repo, create local commits after changes
- When writing commit messages, NEVER auto-add your agent name as co-author
- Only push to remote whenever I instruct you to
- Never create or enable GitHub CI, including GitHub Actions workflows, unless I explicitly ask you to.
  Keep tests and local verification available.
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- Use direct image-reading tools to inspect images and terminal-based checks to validate terminal UIs.
  Reserve computer use for actual browser or desktop tasks, not browser-rendered previews of terminal output.
- When writing or substantially editing long Markdown files, put each full sentence on its own line.
  Preserve normal Markdown structure, but avoid wrapping multiple sentences onto one physical line.
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- When doing bug fixes, always start by reproducing the bug in an E2E setting as closely aligned with the end-user experience as possible.
  This makes sure you find the real problem so your fix will actually solve it.
- Keep a high standard for UI polish, lint, tests, and test reliability.
  Fix problems caused by or blocking the requested change, then rerun the affected checks.
  Report unrelated issues and expand scope only with approval.
- Be my helpful assistant by suggesting the next steps to improve or work towards completing the project after you have finished a major task.
- By default, never spawn subagents or delegate work unless the user explicitly asks for subagents for the current task.
  Work directly by default; per-task permission does not carry over to later tasks or follow-up prompts.
  Exception: if the session's repository instructions explicitly assign you the Firstmate supervisor role ("You are the first mate") or its persistent secondmate role, you have standing authorization to spawn subagents and delegate whenever useful within the user's requested scope, including later tasks and follow-up prompts.
  Merely mentioning Firstmate or working on a project it manages does not qualify for this exception.
- Always initialize an AGENTS.md in a repo if there is not one already.
- Always ensure the repository root has a `CLAUDE.md` that imports `AGENTS.md` using `@AGENTS.md`.
  Keep shared instructions in `AGENTS.md` rather than duplicating them, and preserve any existing Claude-specific guidance.
- Ensure the AGENTS.md is a living document - kept up to date, deduped, and not bloated.
- When using subagents, use GPT-5.6 Luna on High effort and limit delegation to the scope the user requested.
