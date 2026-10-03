---
type: Overview
title: Quickstart
description: What kgbo-stack is, what each file in it is for, and which page or document to read for a given task.
tags: [quickstart, overview, stack]
verified:
  - by: owcli/v0.1.0
    at: "2026-10-03T16:03:45.638Z"
sources:
  - id: openwiki-source-ddd99e512061ee9eb0ed82e9
    resource: repo://.kata.toml
  - id: openwiki-source-47d02fca3524898d5aae2b3b
    resource: repo://LICENSE
  - id: openwiki-source-23775c3de52f3ab95a13cb8b
    resource: repo://README.md
  - id: openwiki-source-1a91849fbfee35c0f5eed2a6
    resource: repo://stack.toml
generated: { by: "owcli/v0.1.0", at: "2026-10-03T16:03:45.720Z" }
---

# Quickstart

kgbo-stack is the organizational repository for a local "Atlassian suite"
for agent-driven development: **k**ata (issue tracker), **g**oatlassian
(portfolio across repositories), **b**ossman (agent session archive and
metrics), and **o**wcli (grounded repository wiki). It holds no code. It
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
| `docs/publishing.md` | publishing and releasing our tools (owcli, bossman, goatlassian) |
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
| see open bundle-level work | `kata list` in this repository |

## The tools

Our tools are public under `github.com/Hoodoo/`: `owcli`, `bossman`, and
`goatlassian` (checked out locally as `~/AISlop/oatlassian`). kata comes
from `github.com/kenn-io/kata`. Each of our tools has its own owcli wiki in
its repository; search across all of them from a member repository once
they are grouped with `owcli workspace create`.
