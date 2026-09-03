---
name: readme-creation
description: Creates or substantially improves concise repository README files for first-time users. Use when a README should explain the project's purpose and shortest successful path without duplicating detailed documentation.
---

# README Creation

Create the shortest README that lets an unfamiliar reader understand the project, decide whether it fits their needs, and complete the primary task successfully.
Treat concision as a core requirement, not a final editing pass.

## Core principles

- Lead with the project's purpose and the shortest verified path to a useful result.
- Include only information needed by the README's primary audience.
- Prefer one strong example over a catalog of possibilities.
- Remove repetition, promotional language, obvious explanations, and source-tree narration.
- Link to focused documentation instead of reproducing it in the README.
- Prefer verified facts and runnable commands.
- Never invent features, prerequisites, defaults, compatibility claims, environment variables, or commands.
- Clearly label anything that could not be verified.
- Do not expose credentials, private URLs, personal paths, or machine-specific state.

## Establish the essential user journey

Before writing, determine:

1. What the project does and who it is for.
2. The primary task a first-time user should complete.
3. The minimum prerequisites for that task.
4. The shortest installation and usage path.
5. A command or observable result that confirms success.

Infer these from the repository when safe.
Ask the user only when missing information would materially change the instructions.

## Investigate selectively

Read applicable instruction files and the existing README before editing.
Inspect only the sources needed to verify claims and commands, such as package manifests, entry points, configuration examples, bootstrap scripts, tests, and existing focused documentation.

Trace important commands to their implementation when practical.
Record prerequisites, working directories, side effects, prompts, and expected results only when readers need them to succeed safely.
Do not turn repository investigation into an exhaustive README inventory.

## Keep the structure minimal

A concise README usually needs:

1. Project name and a one-sentence purpose.
2. A quick start with prerequisites, copy-pasteable commands, and a success check.
3. Essential usage or configuration that most readers need next.
4. Links to deeper documentation, support, contribution guidance, security information, or licensing when relevant.

Add another section only when omitting it would block or seriously mislead the primary audience.
Do not add boilerplate sections, exhaustive option references, long architecture tours, complete repository trees, or troubleshooting catalogs by default.

For monorepos or complex products, keep the root README as a concise entry point and link to component or task-specific documentation.

## Write compact executable instructions

- Keep command sequences in execution order.
- State the working directory or platform only when it is not obvious.
- Use the repository's actual package manager and pinned tooling.
- Make placeholders unmistakable and explain only those that are not self-evident.
- Warn before permission prompts, destructive actions, restarts, or significant side effects.
- Keep expected output outside copyable command blocks.
- Separate platform paths only when their commands genuinely differ.

Document the smallest useful configuration example.
Explain required values, important defaults, and secret handling, then link to a complete configuration reference when one exists.

Include troubleshooting only for common blockers in the documented quick start.
Use a recognizable symptom, likely cause, and concrete recovery step.
Link uncommon failures to deeper documentation or issue tracking.

## Edit for concision

After drafting, challenge every section, paragraph, sentence, example, and badge.
Remove anything that does not help the primary reader choose, start, verify, or find the next source of detail.

Prefer:

- A sentence over a paragraph.
- A short paragraph over a list.
- One canonical workflow over several equivalent alternatives.
- A link over duplicated detail.
- Direct language over background exposition.

Preserve necessary safety warnings and platform differences even when shortening.
Do not achieve concision by making commands ambiguous or omitting required prerequisites.

## Validate

Treat documentation commands as code.
Run the quick start, verification command, and relevant documentation checks when practical.
Confirm paths, links, code fences, placeholders, platform labels, and rendered Markdown.

Perform a final stranger test:

- Can a new reader state what the project does?
- Can they reach a successful first result without inspecting the source?
- Can they find deeper information without the README duplicating it?
- Is anything present that they do not need yet?

If a supported path cannot be tested, state that limitation in the completion report rather than expanding the README with speculation.

## Completion report

Briefly state what changed, what was verified, and any important path that could not be tested.
