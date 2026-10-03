# Installing the stack and pointing it at your projects

The goal is not "install these four binaries"; it is to give every agent
that works in your repositories the same working environment:

- a **tracker** it records intent in (kata, or beads),
- a **knowledge base** it reads before guessing and updates after merges
  (owcli, or upstream OpenWiki),
- **session archiving** so its work can be reviewed and costed (bossman),
- a **portfolio** view for you across all of it (goatlassian).

Roles and providers are declared in [`../stack.toml`](../stack.toml).

## 0. Choose one provider per role

| role      | default     | alternative       | pick the alternative when                             |
| --------- | ----------- | ----------------- | ----------------------------------------------------- |
| tracker   | kata        | beads (`bd`)      | the repo already uses `.beads/`, or issues must live in git |
| knowledge | owcli       | OpenWiki          | you want the upstream tool and have a model API key   |
| sessions  | bossman     | —                 |                                                       |
| portfolio | goatlassian | —                 |                                                       |

**One provider per role per agent host.** Installing both is fine; wiring
both into an agent is not: agents mix up OpenWiki's MCP server and skill
with owcli's AGENTS.md instructions, and two trackers mean two places
intent might be. Keep the inactive provider's agent integration removed
(`openwiki integrations uninstall claude`, no `bd setup claude`).

goatlassian currently reads only kata and owcli; repositories using beads
or OpenWiki still get git and session tracking, but no issue or wiki
signals (tracked in this project).

## 1. Prerequisites

- git, and Go ≥ 1.22 (until prebuilt binaries exist)
- `~/.local/bin` on `PATH`
- Node.js only for the alternatives (beads, OpenWiki)

## 2. Install the binaries

```sh
# tracker
curl -fsSL https://katatracker.com/install.sh | bash      # or: npm install -g @beads/bd

# knowledge
go install github.com/Hoodoo/owcli/cmd/owcli@latest       # or: npm install -g openwiki

# sessions and portfolio
go install github.com/Hoodoo/bossman/cmd/bossman@latest
go install github.com/Hoodoo/goatlassian/cmd/goatlassian@latest
```

To hack on them instead, clone `github.com/Hoodoo/<tool>` and run
`make install` (installs to `~/.local/bin`).

Check: `kata health`, `owcli --version`, `bossman --version`, `goatlassian services`.

## 3. Machine-wide setup (once)

```sh
# keep sessions before Claude Code deletes them (30 days by default)
( crontab -l 2>/dev/null; echo '17 * * * * $HOME/.local/bin/bossman sync >/dev/null' ) | crontab -
bossman sync

# Claude Code: session-close skill bossman uses to tell finished from interrupted sessions
mkdir -p ~/.claude/skills/session-catalogue-close
curl -fsSL https://raw.githubusercontent.com/Hoodoo/bossman/main/skills/session-catalogue-close/SKILL.md \
  -o ~/.claude/skills/session-catalogue-close/SKILL.md
```

If you chose owcli, make sure OpenWiki is not wired into your agents:
`claude mcp list` should not show `openwiki`, and `~/.claude/skills/openwiki`
should not exist. `openwiki integrations uninstall claude` (and `codex`)
removes the wiring but keeps the `openwiki` binary for humans. owcli's
Makefile has both directions for when you need upstream for parity tests:

```sh
make -C <owcli> openwiki-install     # sudo npm install -g + integrations for OPENWIKI_HOSTS (cursor claude)
make -C <owcli> openwiki-uninstall   # stop its MCP server, remove integrations, sudo npm uninstall -g
```

owcli's parity tests need upstream, not its agent integrations: the
wiki-format tests read a checkout (`OWCLI_UPSTREAM_DIR=<openwiki checkout>`),
the search tests the npm package (`OWCLI_UPSTREAM_PKG="$(npm root -g)/openwiki"`).
`openwiki-install` also wires the integrations back in, so remove them
again afterwards.

## 4. Onboard each existing repository

Run in the repository root. Everything here writes committed files
(`.kata.toml`, managed blocks in `AGENTS.md`), so do it on a branch if the
repository has reviewers. For repositories where you cannot add files, skip
to goatlassian: it never writes into a repository.

```sh
cd ~/src/myrepo

# tracker (kata)
kata init --with-agents            # .kata.toml + kata block in AGENTS.md
kata init --with-hooks             # Claude Code work.attention hooks (.claude/)
kata init --with-codex-hooks       # if you use Codex
#   beads instead: bd init; paste `bd onboard` into AGENTS.md; bd setup claude

# knowledge (owcli)
owcli agents-md                    # owcli block in AGENTS.md (and CLAUDE.md if separate)
#   then, in an agent session: "initialize the owcli wiki"  (agent runs owcli run …; no API key)
#   or with an API key:        owcli init
#   OpenWiki instead: openwiki --init; openwiki integrations install claude --project .

git add .kata.toml AGENTS.md CLAUDE.md .claude openwiki 2>/dev/null
git commit -m "Agent environment: kata + owcli"
```

## 5. Group related repositories

Each tool has its own grouping; set up all three for a group of repos that
belong together (a product, a client, this stack).

```sh
# shared wiki search across the group
owcli workspace create shop ~/src/shop-api ~/src/shop-web ~/src/shop-infra

# kata already has one project per repo (from kata init); nothing to group

# portfolio: one goatlassian project per repository, grouped by a tag
goatlassian discover               # what kata/owcli/bossman know, and what is uncovered
goatlassian discover --adopt       # a project for every uncovered repo (or: goatlassian adopt <dir>)
for p in shop-api shop-web shop-infra; do goatlassian project edit $p -t shop; done
goatlassian status -t shop
```

## 6. Verify the environment

```sh
goatlassian services start         # kata daemon, owcli serve, bossman serve
goatlassian status                 # flags: stuck, needs-human, stale, wiki-behind, …
owcli check                        # in each repo: exit 0 = wiki current
goatlassian serve --open
```

An agent session started in an onboarded repository should, unprompted,
search kata before creating work, mark `work.attention`, and consult the
wiki for architecture questions. If it reaches for an `openwiki_*` MCP tool
in an owcli repo, step 3's cleanup did not take.

## Example: this stack itself

```sh
owcli workspace create kgbo-stack ~/AISlop/kgbo-stack ~/AISlop/owcli ~/AISlop/bossman ~/AISlop/oatlassian
goatlassian adopt ~/AISlop/kgbo-stack
goatlassian adopt ~/AISlop/bossman                 # owcli and oatlassian are already projects
goatlassian attach kgbo-stack owcli-workspace kgbo-stack
for p in kgbo-stack owcli bossman oatlassian; do goatlassian project edit $p -t kgbo; done
goatlassian status -t kgbo
```
