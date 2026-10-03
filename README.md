# kgbo-stack

A local "Atlassian suite" for agent-driven development, treated as one
bundle: **k**ata, **g**oatlassian, **b**ossman, **o**wcli.

The bundle is defined by the working environment it gives agents, not by
the tools. Each **role** is a job that environment needs; each **provider**
is a tool that can do it. Pick one provider per role.

| role      | does                                              | default     | alternatives |
| --------- | ------------------------------------------------- | ----------- | ------------ |
| tracker   | system of record for intent and attention         | kata        | beads        |
| knowledge | grounded repository wiki, read just in time       | owcli       | OpenWiki     |
| sessions  | archive and measure Claude Code / Codex sessions  | bossman     |              |
| portfolio | one view across repos: in flight, stale, cost     | goatlassian |              |

- [`stack.toml`](stack.toml): roles, providers, and their install, check,
  onboarding, and agent-host commands. The source of truth for the docs.
- [`docs/install.md`](docs/install.md): install the stack and point it at
  existing repositories.
- [`docs/publishing.md`](docs/publishing.md): runbook for publishing the
  in-house tools to GitHub.

This repository is also where bundle-level work is tracked: tools not yet
published or without an install method, and gaps between roles and
providers. See `kata list` here.
