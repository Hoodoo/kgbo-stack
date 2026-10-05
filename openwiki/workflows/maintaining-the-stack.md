---
type: Workflow
title: Maintaining the Stack
description: How to onboard a repository onto the stack, add a tool or provider, publish and release one of our tools, and keep stack.toml, the docs, and the kata issues in this repository consistent.
tags: [workflow, onboarding, publishing, release, kata]
verified:
  - by: owcli/v0.2.0
    at: "2026-10-05T08:25:42.215Z"
sources:
  - id: openwiki-source-ddd99e512061ee9eb0ed82e9
    resource: repo://.kata.toml
  - id: openwiki-source-4295305d9bd805a055f92696
    resource: repo://bin/kgbo
  - id: openwiki-source-07dce1e07e2253eab6205a2e
    resource: repo://docs/install.md
  - id: openwiki-source-b4b124a71e74ba72bfbe44ae
    resource: repo://docs/publishing.md
  - id: openwiki-source-47d02fca3524898d5aae2b3b
    resource: repo://LICENSE
  - id: openwiki-source-1a91849fbfee35c0f5eed2a6
    resource: repo://stack.toml
generated: { by: "owcli/v0.2.0", at: "2026-10-05T08:25:42.315Z" }
---

# Maintaining the Stack

kgbo-stack's only code is `bin/kgbo`, the data-bundle script. Maintaining
the repository means keeping three things in step: the manifest
(`stack.toml`), what is derived from it (`docs/install.md`,
`docs/data-bundle.md`, `docs/publishing.md`, and `bin/kgbo`, which reads it
at run time), and the kata issues in this
repository that track bundle-level work. The tools themselves live and are
released in their own repositories.

## Onboarding a repository

`docs/install.md` is the procedure; its steps map onto the providers'
`install`, `host.*`, and `onboard` commands in
[Roles and Providers](../concepts/roles-and-providers.md):

1. Choose one provider per role (step 0) and install the binaries (step 2).
2. Machine-wide setup once (step 3): a cron entry for `bossman sync`, the
   `session-catalogue-close` skill fetched from the bossman repository,
   and making sure upstream OpenWiki is not wired into agents when owcli is
   the knowledge provider.
3. In each repository (step 4): `kata init --with-agents`, `kata init
   --with-hooks` (and `--with-codex-hooks`), `owcli agents-md`, then have an
   agent initialize the wiki. These write committed files, so use a branch
   where the repository has reviewers.
4. Group related repositories (step 5): an owcli workspace for shared wiki
   search, and a goatlassian tag across the per-repository projects
   (`goatlassian status -t <tag>`).
5. Verify (step 6) with `goatlassian services start`, `goatlassian status`,
   and `owcli check` per repository.

## Backing up the stack's state

`bin/kgbo snapshot DEST` copies every provider's machine-local state into
`DEST`, with SQLite databases taken through the online backup API, so it is
safe while the tools run; never copy the live directories with plain `tar`.
To keep that state in one directory in the first place, stop the tools and
run `bin/kgbo adopt`. See [Data Bundle](../concepts/data-bundle.md).

## Adding a provider or tool

1. Add a `[providers.<name>]` table to `stack.toml` with its `role` and the
   keys that apply (`install`, `check`, `onboard`, `host.*`, `markers`,
   `conflicts`, `goatlassian_kind`, and, if it keeps state outside
   repositories, `home_env`, `home_default`, `bundle_dir`). Keep every
   command copy-pasteable.
2. If it is an alternative to an existing provider, add the pair to each
   other's `conflicts` when both would face agents.
3. Update `docs/install.md` (and the README table) from the manifest.
4. If goatlassian cannot read it, leave `goatlassian_kind` empty and file a
   kata issue here; the beads and OpenWiki adapters are tracked that way.

A new role is a larger change: add `[roles.<name>]` with `purpose`,
`contract`, and `default`, then a provider for it.

## Publishing one of our tools

`docs/publishing.md` holds the per-tool preflight, kept as a checklist for
the next tool added to the stack: land work on `main`, give the Go module
its `github.com/Hoodoo/<tool>` import path so `go install` works, fall back
to the build-info version when no `-ldflags` are set, add `LICENSE` and a
README, ship agent-facing assets (such as skills) in the repository, scan
history for secrets, refresh the tool's wiki after the change, and tag.

All four repositories are public and MIT-licensed; owcli, bossman, and
goatlassian were first released as `v0.1.0`; owcli is at `v0.2.0`, which
adds `OWCLI_HOME`, and goatlassian at `v0.1.1`, which pins owcli-wiki
components by repository root.

## Releasing

Tag in the tool's repository: `git tag -a vX.Y.Z -m vX.Y.Z && git push
origin vX.Y.Z`. `go install …@latest` resolves the highest semver tag, and
the binary reports that version from its build info. Prebuilt binaries are
not produced yet.

## Tracking work here

This repository's kata project (`.kata.toml`, project `kgbo-stack`) tracks
work that belongs to the bundle rather than to one tool: tools not yet
published or without an install method, and gaps between roles and
providers (for example missing goatlassian adapters, prebuilt releases, and
a `kgbo` installer that reads `stack.toml`). Run `kata list` in this
repository to see them; follow `AGENTS.md` for the kata workflow.
