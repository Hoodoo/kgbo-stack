---
type: Overview
title: Quickstart
description: What kgbo-stack is, what each file in it is for, and which page or document to read for a given task.
tags: [quickstart, overview, stack]
verified:
  - by: owcli/v0.2.0-1-g3d84f34
    at: "2026-10-05T08:58:22.198Z"
sources:
  - id: openwiki-source-ddd99e512061ee9eb0ed82e9
    resource: repo://.kata.toml
  - id: openwiki-source-4295305d9bd805a055f92696
    resource: repo://bin/kgbo
  - id: openwiki-source-6215ef1e20210625bdbea089
    resource: repo://docs/data-bundle.md
  - id: openwiki-source-47d02fca3524898d5aae2b3b
    resource: repo://LICENSE
  - id: openwiki-source-012f2c78e3b1446dfc35803f
    resource: repo://Makefile
  - id: openwiki-source-23775c3de52f3ab95a13cb8b
    resource: repo://README.md
  - id: openwiki-source-1a91849fbfee35c0f5eed2a6
    resource: repo://stack.toml
generated: { by: "owcli/v0.2.0-1-g3d84f34", at: "2026-10-05T08:58:07.074Z" }
---

# Quickstart

kgbo-stack is the organizational repository for a local "Atlassian suite"
for agent-driven development: **k**ata (issue tracker), **g**oatlassian
(portfolio across repositories), **b**ossman (agent session archive and
metrics), and **o**wcli (grounded repository wiki). Its only code is `bin/kgbo`, a small script for the data bundle and for moving repositories. It
defines how the tools form one bundle, documents how to install the bundle
and point it at existing repositories, and tracks bundle-level work in its
own kata project.

The bundle is defined by roles, not tools: each role is a job the agents'
working environment needs, and each provider is a tool that can do it
(kata or beads for tracking, owcli or upstream OpenWiki for knowledge). See
[Roles and Providers](concepts/roles-and-providers.md).

## Files

| file | purpose |
| --- | --- |
| `README.md` | front door: the role table with links to every provider's repository, and a quick install |
| `stack.toml` | the manifest: roles, providers, and their install, check, onboarding, and agent-host commands; the source of truth for the docs |
| `docs/install.md` | installing the stack and onboarding existing repositories |
| `docs/data-bundle.md` | keeping all of the stack's state in one directory, and consistent backups |
| `docs/moving.md` | rewriting stored paths after repositories move or on a new machine |
| `docs/publishing.md` | publishing and releasing our tools (owcli, bossman, goatlassian) |
| `bin/kgbo` | the bundle tool: `env`, `homes`, `snapshot`, `adopt`, `remap`; reads `stack.toml` |
| `deploy/container/`, `Makefile` | the container image for the stack's services (`make image`) |
| `docs/container.md` | running that image with the bundle as a volume |
| `AGENTS.md` | agent instructions: the kata workflow and owcli wiki routing |
| `.kata.toml` | binds this repository to the `kgbo-stack` kata project |
| `LICENSE` | MIT |

## Where to look

| If you need to… | Read |
| --- | --- |
| understand what a role or provider is, or why two providers conflict | [Roles and Providers](concepts/roles-and-providers.md) |
| install the stack or onboard a repository | `docs/install.md`, summarized in [Maintaining the Stack](workflows/maintaining-the-stack.md) |
| add a provider or tool | [Maintaining the Stack](workflows/maintaining-the-stack.md) |
| publish or release a tool | `docs/publishing.md` and [Maintaining the Stack](workflows/maintaining-the-stack.md) |
| move state into one directory, or back it up | `docs/data-bundle.md` and [Data Bundle](concepts/data-bundle.md) |
| build or run the services in a container | `docs/container.md` and [Container Image](operations/container.md) |
| move repositories or set up a new machine | `docs/moving.md` and [Moving Repositories or Machines](workflows/moving-repositories.md) |
| see open bundle-level work | `kata list` in this repository |

## The tools

Our tools are public under `github.com/Hoodoo/`: `owcli`, `bossman`, and
`goatlassian` (checked out locally as `~/AISlop/oatlassian`). kata comes
from `github.com/kenn-io/kata`. Each of our tools has its own owcli wiki in
its repository; search across all of them from a member repository once
they are grouped with `owcli workspace create`.
