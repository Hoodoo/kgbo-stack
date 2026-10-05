---
type: Concept
title: Roles and Providers
description: How stack.toml defines the bundle as roles filled by interchangeable providers, what each role and provider declares, and why only one provider per role may face agents.
tags: [stack, roles, providers, manifest]
verified:
  - by: owcli/v0.2.0
    at: "2026-10-05T08:11:18.759Z"
sources:
  - id: openwiki-source-07dce1e07e2253eab6205a2e
    resource: repo://docs/install.md
  - id: openwiki-source-1a91849fbfee35c0f5eed2a6
    resource: repo://stack.toml
generated: { by: "owcli/v0.2.0", at: "2026-10-05T08:11:36.857Z" }
---

# Roles and Providers

kgbo-stack defines the bundle by the working environment it gives coding
agents, not by a fixed list of tools. `stack.toml` is the manifest: it
declares **roles** (jobs the environment needs done) and **providers**
(tools that can do a role). A machine chooses one provider per role. The
manifest is declared the source of truth for `docs/install.md` and
`docs/publishing.md`, and is meant to be read by a future `kgbo` installer,
so every command in it must be copy-pasteable as written.

## Roles

Each `[roles.<name>]` table has a `purpose`, a `contract` (what any provider
of the role must offer for the rest of the stack to work), and a `default`
provider.

| role        | purpose                                              | default       |
| ----------- | ---------------------------------------------------- | ------------- |
| `tracker`   | system of record for intent, ownership, blockers, and what needs a human | `kata` |
| `knowledge` | repository memory: a wiki agents read just in time and update after merges | `owcli` |
| `sessions`  | keep, browse, and measure agent sessions before the hosts delete them | `bossman` |
| `portfolio` | one view across repositories: in flight, stale, needs a human, cost | `goatlassian` |

The contracts are what make providers interchangeable. A tracker must keep
its agent instructions between managed markers in `AGENTS.md` (or inject
them with a hook), resolve one project per repository from the repository
root, and emit `--json`. A knowledge provider must keep a wiki per
repository, group wikis into workspaces, and offer a model-free check of
whether the wiki is current. The portfolio role only reads the others
through their CLIs and never writes into repositories.

## Providers

Each `[providers.<name>]` table names its `role` and records how to operate
it. Keys are optional; a provider declares the ones that apply:

| key | meaning |
| --- | --- |
| `upstream` / `repo` | third-party source, or our own repository |
| `local` | where our own tools are checked out on the maintainer's machine |
| `ours` | whether this project publishes it |
| `install`, `update`, `check` | machine-level commands |
| `onboard` | what to run inside a repository (`{repo}`) to adopt it |
| `host.claude`, `host.codex` | wiring into an agent host |
| `uninstall_host` | removing that wiring (`{host}` placeholder) |
| `markers` | the managed-block markers the provider writes into `AGENTS.md` |
| `conflicts` | providers of the same role that must not face agents at the same time |
| `goatlassian_kind` | the goatlassian component kind that reads it; empty means no adapter yet |
| `home_env`, `home_default`, `bundle_dir` | where the provider keeps state outside repositories: its home variable, its default directories, and its directory in the data bundle |
| `snapshot_skip` | file or directory patterns a snapshot of its state leaves out |

The `[bundle]` table and the bundle keys describe the
[Data Bundle](data-bundle.md): one directory for all of the stack's
machine-local state.

The declared providers are `kata` and `beads` (tracker), `owcli` and
`openwiki` (knowledge), `bossman` (sessions), and `goatlassian`
(portfolio). Our own tools (`owcli`, `bossman`, `goatlassian`) install with
`go install github.com/Hoodoo/<tool>/cmd/<tool>@latest`; kata uses its own
install script, beads and OpenWiki are npm packages.

## One agent-facing provider per role

Installing two providers of a role is fine; wiring both into an agent host
is not. Agents confuse OpenWiki's MCP server and skill with owcli's
`AGENTS.md` instructions, and two trackers give intent two homes. That is
why `owcli` and `openwiki` list each other in `conflicts`, and why the
install guide tells you to keep the inactive provider's integration
removed (`openwiki integrations uninstall claude`, no `bd setup claude`).
owcli's own Makefile wraps installing and removing upstream OpenWiki for
parity testing.

## Gaps the model exposes

goatlassian reads only kata, owcli, and bossman. `beads` and `openwiki`
have an empty `goatlassian_kind`, so repositories using them get git and
session data in the portfolio but no issue or wiki signals. Closing that gap
is tracked as a kata issue in this repository; see
[Maintaining the Stack](../workflows/maintaining-the-stack.md).
