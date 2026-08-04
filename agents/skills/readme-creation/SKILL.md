---
name: readme-creation
description: Creates or substantially improves repository README files for first-time users. Use when a README must clearly explain what a repository is for and provide accurate, copy-pasteable installation, configuration, usage, verification, troubleshooting, and development instructions.
---

# README Creation

Create a README that lets someone unfamiliar with the repository understand its purpose, decide whether it fits their needs, and successfully use it without relying on undocumented knowledge.
Treat the README as a tested user interface rather than a description of the source tree.

## Core principles

- Write for a capable reader who has never seen the repository.
- Put the shortest successful path near the beginning.
- Prefer verified facts and runnable commands over promotional language.
- Never invent features, prerequisites, defaults, compatibility claims, environment variables, or commands.
- Clearly label anything that could not be verified.
- Explain why a step is necessary when that reason is not obvious.
- Keep platform-specific commands in separately labeled sections.
- Do not expose credentials, private URLs, personal paths, or machine-specific state.
- Preserve useful existing documentation and link to detailed documents instead of duplicating them without need.

## 1. Establish scope and audience

Before writing, determine:

1. Which README is in scope and what directory or package it represents.
2. Whether the primary audience is end users, operators, library consumers, contributors, or a combination of them.
3. The main task a first-time user should be able to complete.
4. The supported operating systems, runtimes, package managers, and deployment environments.
5. Whether the repository is public, internal, experimental, or production-ready.

If any answer materially affects installation or usage and cannot be inferred safely, ask the user rather than guessing.

## 2. Investigate the repository

Read all applicable instruction files before changing documentation.
Inspect the repository deeply enough to verify the user journey, including as relevant:

- Existing README files and documentation directories.
- Package manifests, lockfiles, workspace definitions, and runtime constraints.
- CLI entry points and built-in `--help` output.
- Application entry points, exported APIs, and public configuration schemas.
- Bootstrap, installation, migration, deployment, and teardown scripts.
- Example projects, fixtures, screenshots, and sample configuration.
- Environment variable references and example environment files.
- Test, lint, format, build, and development commands.
- CI workflows and release configuration.
- License, support, security, and contribution files.

Trace commands to their implementation when practical.
Do not assume a script name describes its behavior accurately.
Record prerequisites, required working directories, side effects, expected output, and failure modes.

## 3. Design the first-time user journey

Define a minimal path that starts from the least configured supported environment and ends with a visible success condition.
The path should answer these questions in order:

1. What is this repository?
2. Why would I use it?
3. What do I need before starting?
4. How do I install or obtain it?
5. What exact command do I run first?
6. What should success look like?
7. What should I do next?

Keep the quick start focused on one representative success path.
Move alternatives and advanced options into later sections.
If different platforms require different commands, provide separate complete paths rather than mixing shell dialects in one block.

## 4. Choose an appropriate structure

Use only sections that help this repository's readers.
A strong default order is:

1. Project name and one-sentence purpose.
2. A short explanation of the problem it solves and intended use cases.
3. Key capabilities, with limitations or non-goals where useful.
4. Prerequisites with supported versions and required accounts or permissions.
5. Quick start with copy-pasteable commands and a success check.
6. Common usage workflows with realistic examples.
7. Configuration, including locations, precedence, defaults, and secrets handling.
8. Architecture or repository layout when readers need it to operate or modify the project.
9. Development setup and validation commands.
10. Troubleshooting organized by observable symptoms.
11. Upgrade, migration, uninstall, or cleanup instructions when applicable.
12. Security, support, contributing, and license links.

Do not add empty boilerplate sections.
Do not lead with a large architecture discussion when users need installation instructions first.

## 5. Write executable instructions

For every command sequence:

- State which terminal, operating system, container, or host should run it.
- State the required working directory when it is not obvious.
- Use the repository's actual package manager and pinned tooling.
- Keep commands in execution order.
- Make placeholders visually unmistakable and explain how to obtain their values.
- Mention prompts, restarts, permission requests, destructive effects, and long-running steps before they occur.
- Include a verification command or observable result.
- Avoid combining unrelated operations into opaque one-liners.

Use command blocks that can be copied without also copying shell prompts or expected output.
Put expected output in a separate block or describe it in prose.
Use `sh` only for portable shell commands, and use `bash`, `zsh`, `powershell`, or another specific language when syntax requires it.

## 6. Explain configuration precisely

Document configuration from the user's perspective.
Include, when applicable:

- Configuration file paths and discovery rules.
- Environment variables and whether they are required or optional.
- Defaults and precedence between flags, environment variables, and files.
- A minimal valid example.
- Reload or restart requirements.
- Safe secret-storage guidance.
- Platform-specific differences.

Never include real secrets in examples.
Use clearly fake values that cannot be mistaken for working credentials.

## 7. Make troubleshooting actionable

Write troubleshooting entries around symptoms a new user can recognize.
Each entry should include:

1. The exact symptom or representative error.
2. The most likely cause.
3. A diagnostic command or check.
4. A concrete recovery procedure.
5. A link to deeper documentation when available.

Avoid advice such as "check your setup" without explaining what to check.

## 8. Validate the README

Treat all documentation commands as code.
Run the repository's existing documentation checks, formatters, and link checkers when available.
Then validate manually:

- Follow the quick start from a clean temporary directory, container, or least-configured available environment when practical.
- Run help, version, build, test, and verification commands exactly as written.
- Confirm file paths, headings, anchors, internal links, and external links.
- Confirm code fences use the correct language.
- Confirm every placeholder is defined.
- Confirm platform labels are unambiguous.
- Confirm the README does not promise unsupported behavior.
- Confirm setup and cleanup instructions do not destroy existing user data unexpectedly.
- Review the rendered Markdown, not only the source.

If a supported platform is unavailable, statically inspect that path and state the validation limitation in the final report.
Do not present untested platform behavior as verified.

## 9. Perform a stranger test

Before finishing, reread the README as someone who knows nothing about the repository.
Verify that the reader can answer all of the following without inspecting source code:

- What does this project do?
- Who is it for?
- What does it not do?
- What must be installed or configured first?
- Which commands should be run, where, and in what order?
- How can success be confirmed?
- How are common tasks performed after installation?
- Where is configuration stored?
- How can common failures be diagnosed and fixed?
- Where can the reader get more detail or help?

Revise any section that depends on implicit repository knowledge.

## Completion report

Summarize:

- The user journeys documented or improved.
- The source files and commands used to verify accuracy.
- The validation performed.
- Any platform paths or external services that could not be tested.
- Any unresolved documentation gaps that require maintainer input.
