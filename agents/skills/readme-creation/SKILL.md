---
name: readme-creation
description: Create or substantially improve polished repository READMEs with clear product positioning, a branded header, verified quick start, authentic visuals, and a concise directory layout. Use for first-time-user repository introductions without duplicating detailed documentation.
---

# README Creation

Make the README a polished product introduction and a reliable starting point.
A reader should quickly understand the value, reach a useful first result, and find the right next destination.
Use restrained branding, concrete evidence, and deliberate editing; visual polish should make useful information easier to find.

## Establish the facts and scope

Read applicable instructions, the existing README, and any supplied reference.
Inspect manifests, entry points, scripts, tests, and focused documentation to verify the audience, main workflow, prerequisites, supported platforms, current capabilities, and important limitations.
Trace documented commands to their implementation when practical.
Ask only when missing information materially changes the outcome.

Respect the requested scope during revisions.
Keep suitable branding and visuals when the user asks for editorial improvements; do not turn selective edits into an unrequested redesign or media production task.
Never invent features, statistics, licenses, compatibility, published packages, commands, or destinations.
Exclude credentials, private URLs, personal paths, and machine-specific state.

## Give the opening a clear job

Default to a compact centered header using GitHub-compatible HTML:

- A legible logo with explicit dimensions and descriptive alternative text.
- The project name as the single main heading.
- A specific, outcome-focused tagline that explains why someone would use the project.
- A brief supporting description of what it does, where it works, and any defining constraint or benefit.
- A small navigation row for starting, seeing the product, and finding useful documentation.
- Optional verified facts that add information instead of repeating the supporting copy.

Prefer concrete verbs and outcomes to vague promises, fragmented slogans, or claims of being powerful, seamless, or revolutionary.
Keep enough product context that the tagline makes sense to someone who has never seen the repository.

Reuse suitable existing branding.
When logo creation is in scope, create an original mark appropriate to the product, preferably an editable vector for simple geometry; use image-generation capabilities when bitmap artwork is appropriate.
Store assets in a stable repository location with relative references.
Do not copy another project's identity or add unnecessary remote asset dependencies.
Check the logo at its actual display size on light and dark backgrounds.
Avoid badge walls, ornamental emoji headings, decorative banners, and repeated calls to action.

## Build a short reader journey

Use this default sequence, adapting labels and omitting irrelevant sections:

1. Branded opening and navigation.
2. Quick start with prerequisites, executable commands, and an observable success result.
3. Authentic preview or example that demonstrates the main experience.
4. One compact explanation of the core workflow and its benefits.
5. Development with a small annotated directory tree and canonical checks.
6. Clear next steps for users, contributors, and people needing help.

Keep the first useful action near the top.
Use the actual package manager and pinned tooling, with commands in execution order and working directories made clear.
Explain installation downloads or other significant side effects before the affected commands.
Make placeholders unmistakable and keep expected output outside copyable command blocks.
Do not advertise registry installation unless the package is available there.
Link alternate installation paths and uncommon troubleshooting to focused documentation.

## Consolidate, then edit

Give each section a distinct purpose and each important explanation one primary home.
A brief positioning claim in the header may be expanded once in the body; avoid restating the same benefits in setup, preview captions, features, and usage.
Use a few concrete benefits tied to implemented behavior, not a complete feature inventory.
Group overlapping explanations into one compact workflow section.

Keep essential installation instructions, prerequisites, and material limitations visible.
Put useful secondary reference material, such as keyboard shortcuts or an occasional configuration example, in a clearly labeled `<details>` block when it would otherwise interrupt the main journey.
Use a blank line after `<summary>` and before `</details>` so embedded Markdown renders correctly.
Link longer reference material rather than hiding a manual in collapsible sections.

Remove repeated prose, equivalent command variants, and sections that do not help readers decide, start, understand, or navigate.
Preserve meaningful safety boundaries while shortening.
Use plain language and short paragraphs; tables should compare information rather than decorate it.
In long Markdown, put each full sentence on its own physical line while preserving normal HTML, lists, tables, and code blocks.
Use normal hyphens rather than em dashes.

## Show evidence of the product

Use a small number of authentic, current visuals or examples when they clarify the experience.
For visual apps, capture the main workflow from the running product using scratch data.
For libraries or command-line tools, real code and output may communicate more effectively than screenshots.
Never present fabricated product behavior as working functionality.
Do not add recordings, galleries, or new assets merely to fill a section, especially during narrowly scoped edits.

Give images descriptive alternative text, deliberate display sizes, and links to full-size versions when useful.
Keep the quick start accessible before a large preview.
Use simple Markdown except where compatible HTML materially improves the header, image arrangement, or secondary reference disclosure.

## Orient contributors without cataloging files

Default to a small annotated `text` tree under Development.
Show the actual root name, main source area, tests, scripts, documentation, and essential build metadata.
Expand the source area only for a handful of entry points or especially useful locations.
Aim for about 8-12 entries total; scale to the repository instead of filling a quota.
A new contributor should understand where to look without reading a file-by-file architecture tour.

Verify every listed path and responsibility against the checkout, and align short annotations.
Do not invent folders to simplify the tree.
Exclude dependency caches, local environments, secrets, and transient reports.
Include generated output only when needed, with its status clearly labeled.
Link detailed architecture and contribution procedures to existing documentation.

## End with useful destinations

Close with a compact set of audience-specific next steps: use or learn more, develop or contribute, and get help or report a problem.
Use an action and a descriptive link for each, with the minimum context needed to proceed.
Point contributors to real setup and validation instructions; do not imply a contribution policy that does not exist.
Tell issue reporters which few details would make their report actionable.
Avoid a generic conclusion, repeated sales pitch, or another installation block.
For monorepos, route readers to the relevant component guides.

## Validate and report

Treat documentation commands as code and verify the quick start and success check when practical.
Reuse relevant validation from the current task when behavior has not changed; do not run unrelated full suites solely for prose edits.
Check numerical claims, paths, links, anchors, fences, image references, and collapsible sections.

Inspect the rendered README at narrow and wide widths, including light and dark backgrounds when supported.
Check logo size, navigation wrapping, preview sizing, tree alignment, and both open and closed disclosure states.
Fix broken assets, page overflow, unreadable text, and accidental HTML rendering problems.
Distinguish local approximate rendering from actual hosted rendering in the completion report.

Read once more as a stranger: is the purpose clear, the first action easy, each explanation necessary, the tree useful, and the next destination obvious?
Report the changes and checks briefly, with any material verification limitation.
Never imply that an unperformed check passed.
