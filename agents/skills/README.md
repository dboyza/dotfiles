# Shared agent skills

Store reusable cross-agent skills in this directory.
Each skill belongs in its own subdirectory with an Agent Skills compatible `SKILL.md` file.
Home Manager exposes this directory at `~/.agents/skills`, which Pi discovers automatically.
Review every skill before adding it because skills can instruct agents to execute code.

Do not copy harness-specific system skills here wholesale.
Only add skills that are portable across the supported coding-agent tools and operating systems.
