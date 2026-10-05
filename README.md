# kgbo-stack

A local "Atlassian suite" for agent-driven development, treated as one
bundle: **k**ata, **g**oatlassian, **b**ossman, **o**wcli.

The bundle is defined by the working environment it gives agents, not by
the tools. Each **role** is a job that environment needs; each **provider**
is a tool that can do it. Pick one provider per role.

| role      | does                                              | default                                              | alternatives                                             |
| --------- | ------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------- |
| tracker   | system of record for intent and attention         | [kata](https://github.com/kenn-io/kata)              | [beads](https://github.com/gastownhall/beads)             |
| knowledge | grounded repository wiki, read just in time       | [owcli](https://github.com/Hoodoo/owcli)             | [OpenWiki](https://github.com/langchain-ai/openwiki)     |
| sessions  | archive and measure Claude Code / Codex sessions  | [bossman](https://github.com/Hoodoo/bossman)         |                                                          |
| portfolio | one view across repos: in flight, stale, cost     | [goatlassian](https://github.com/Hoodoo/goatlassian) |                                                          |

Quick install (details and per-repository onboarding in the install guide):

```sh
curl -fsSL https://katatracker.com/install.sh | bash
go install github.com/Hoodoo/owcli/cmd/owcli@latest
go install github.com/Hoodoo/bossman/cmd/bossman@latest
go install github.com/Hoodoo/goatlassian/cmd/goatlassian@latest
```

- [`stack.toml`](stack.toml): roles, providers, and their install, check,
  onboarding, and agent-host commands. The source of truth for the docs.
- [`docs/install.md`](docs/install.md): install the stack and point it at
  existing repositories.
- [`docs/data-bundle.md`](docs/data-bundle.md): keep all of the stack's
  state in one directory (`bin/kgbo adopt`), and back it up consistently
  (`bin/kgbo snapshot`).
- [`docs/publishing.md`](docs/publishing.md): runbook for publishing the
  in-house tools to GitHub.

This repository is also where bundle-level work is tracked: tools not yet
published or without an install method, and gaps between roles and
providers. See `kata list` here.

## License

MIT
