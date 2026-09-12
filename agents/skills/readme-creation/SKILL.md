---
name: readme-creation
description: Create or substantially improve modern, polished repository READMEs with a branded header, verified quick start, purposeful visuals, and an annotated directory layout. Use for first-time-user repository introductions without duplicating detailed documentation.
---

# README Creation

Create a modern, sleek, professional, informative README that helps an unfamiliar reader understand the project, reach a useful first result, and find their way around the repository.
Use a restrained visual presentation inspired by GPTskins: a centered logo, clear identity, compact navigation, selective product proof, and a curated directory layout.
Adapt this presentation to the project's audience and branding; do not copy another project's identity or force irrelevant sections.

## Verify the user journey

Read applicable instruction files, the existing README, and any user-supplied design reference.
Inspect manifests, entry points, configuration examples, scripts, tests, and focused documentation as needed to establish:

1. What the project does and who it serves.
2. The primary task a first-time user should complete.
3. The minimum prerequisites and shortest installation and usage path.
4. An observable result that confirms success.
5. The real capabilities, limitations, and source locations worth highlighting.

Infer these from the repository when safe.
Ask only when missing information would materially change the result.
Never invent features, compatibility, statistics, licenses, published packages, commands, or links.
Do not expose credentials, private URLs, personal paths, or machine-specific state.

## Build a polished opening

Default to a compact centered hero using GitHub-compatible HTML:

- A project logo with explicit dimensions and meaningful alternative text.
- The project name as the single main heading.
- A short, specific tagline and, if needed, one supporting sentence.
- A small row of links to the quick start, preview, and most useful existing documentation or support destinations.
- A restrained row of verified facts when they help readers decide, such as scope, platform, or offline operation.

Reuse a suitable repository logo first.
When creating a logo is within scope and none exists, make an original mark that fits the product; use a simple editable vector when appropriate, and use image-generation capabilities for bitmap artwork when needed.
Store assets in a stable repository location and use relative references.
Do not repurpose another project's logo or introduce a remote asset dependency without a reason.
Check that the logo remains legible at header size on both light and dark backgrounds.

Prefer typography, whitespace, and a consistent accent palette over decoration.
Avoid badge walls, ornamental emoji headings, unsupported marketing claims, decorative banners, and repetitive calls to action.
Use badges only when their real status helps readers and their source is valid.

## Organize around the reader

Use this default flow, adjusting labels and order when the product calls for it:

1. Branded header and navigation.
2. Install or Quick start, with prerequisites, runnable commands, and a success check.
3. Preview, when an actual screenshot, demo, or short output example materially explains the experience.
4. A compact explanation of the capabilities and workflow readers need next.
5. Development, containing a curated repository layout and the canonical local checks.
6. Links to focused documentation, support, contribution guidance, and licensing where relevant.

Keep the first successful action near the top.
Show a few concrete benefits tied to implemented behavior rather than a feature inventory.
Link to deeper guidance instead of repeating it.
For monorepos, make the root README an entry point to component documentation.
Omit empty or irrelevant sections rather than filling a template.

## Use purposeful visuals

For visual applications, prefer a small number of current, authentic screenshots showing the main experience.
Capture them from the running product with scratch data when possible.
For command-line tools or libraries, a short real terminal transcript or usage example may be a better preview.
Never present concept art or a fabricated screenshot as working product behavior.

Use relative image paths, descriptive alternative text, and deliberate display widths.
Link reduced-size previews to the full image when useful.
Keep visual assets legible without making readers scroll through an oversized gallery before they can start.
Prefer simple Markdown; reserve HTML for the centered hero or a compact image arrangement that improves the rendered result.

## Include a curated directory layout

Default to an annotated `text` tree under Development or Repository layout.
Show the actual root name, key source areas, tests, scripts, assets, and documentation that orient a new contributor.
Use short, aligned descriptions of each location's responsibility.
Expand only subdirectories that help explain the project.

Verify every included path and description against the checkout.
Aim for roughly 8-15 meaningful entries, scaling down for small repositories.
Do not dump the entire tree or include dependency caches, local environments, secrets, or transient reports.
Show a generated output directory only when contributors need to know about it, and label its generated or ignored status accurately.
Keep architecture explanations in focused documentation rather than extending the tree into a file-by-file tour.

## Write executable, concise instructions

Use the repository's actual package manager and pinned tooling.
Keep commands in execution order and state working directories or platform differences when necessary.
Make placeholders unmistakable, keep expected output outside copyable command blocks, and explain important side effects before the command that causes them.
Do not advertise installation from a registry unless that package is actually available.

Document only the smallest useful configuration example and common blockers on the documented path.
For troubleshooting, connect a recognizable symptom to a concrete recovery step; link uncommon failures to deeper guidance.
Avoid multiple equivalent installation paths unless they serve distinct audiences.

Use plain, specific language and short sections.
Put each full sentence on its own physical line in long Markdown, preserving normal lists, tables, and code blocks.
Use normal hyphens rather than em dashes.
Remove repetition and promotional filler while preserving prerequisites, material limitations, and a clear next step.

## Validate the result

Treat documentation commands as code.
Run the quick start, success check, and relevant documentation checks when practical.
Verify local paths, external destinations where needed, heading anchors, image references, code fences, placeholders, and all numerical claims.

Inspect the rendered README, including the hero, logo, preview sizing, tree alignment, and navigation.
Check narrow and wide layouts and light and dark backgrounds when the renderer supports them.
Fix broken images, excessive whitespace, clipping, unreadable text, and accidental HTML rendering problems.

Perform a final stranger test:

- Can a new reader quickly explain what the project does and whether it fits their needs?
- Can they reach a successful first result without reading the source?
- Do the visuals demonstrate the real product?
- Does the directory layout help them find the right code or documentation?
- Does each section earn its space?

Briefly report what changed, what was verified, and any important command or rendering path that could not be tested.
Do not imply that validation was performed when it was not.
