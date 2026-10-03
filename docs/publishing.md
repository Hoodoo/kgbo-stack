# Publishing the stack to GitHub

Runbook for taking the three in-house tools (owcli, bossman, goatlassian)
from local repositories to installable public GitHub repositories, then
publishing this repository as the bundle's front door. kata is already
published upstream and needs nothing.

Each step is tracked as a kata issue in this project (`kata list`); the
epic is "Publish the kgbo stack to GitHub".

## State on 2026-10-03: published

All four repositories are public under `Hoodoo/`, MIT-licensed, with
`main` pushed. The three tools install with `go install
github.com/Hoodoo/<tool>/cmd/<tool>@latest`, verified in an empty GOPATH
with `GOPROXY=direct`; `@latest` resolves to the `v0.1.0` tag and the
binaries report `v0.1.0` from their build info. Each tool's wiki was updated
after the rename and `owcli check` passes. A pattern scan of every
repository's full history found no credentials or `/home/...` paths.

Not done yet: prebuilt binaries (kata issue b4ba).

To release: `git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z` in the
tool's repository; `go install …@latest` picks up the highest semver tag.

The preflight below is kept as the checklist for the next tool added to
the stack.

## Decisions

- **License: MIT for all four.** Every dependency is permissive (MIT,
  BSD-2/3, Apache-2.0: cobra, pflag, toml, goldmark, yaml, modernc sqlite and
  libc, x/*); none is copyleft, so none dictates the project license.
  Apache-2.0 dependencies only require keeping their notices when you
  distribute binaries, which matters once prebuilt releases exist (generate
  a third-party notices file with `go-licenses`). owcli is a clean-room
  reimplementation of OpenWiki, which is itself MIT; the parity tests read
  an upstream checkout from `OWCLI_UPSTREAM_DIR` and copy no upstream code.
- **Repository names** follow the binaries. **Visibility**: public.
- **Commit identity** `kot@kot.so` is already public with the history.

## Per-tool preflight (repeat in each repository)

1. **Land the work on `main`.** owcli: push the 2 unpushed commits.
2. **Rename the Go module** to its import path so `go install` works:

   ```sh
   go mod edit -module github.com/Hoodoo/<tool>
   grep -rl '"<oldmodule>/' --include=*.go . | xargs sed -i 's#"<oldmodule>/#"github.com/Hoodoo/<tool>/#'
   sed -i 's#-X <oldmodule>/internal#-X github.com/Hoodoo/<tool>/internal#' Makefile
   make check
   ```

3. **Version without the Makefile.** `go install …@vX` skips the ldflags, so
   the binary reports `0.0.0-dev`. Fall back to
   `debug.ReadBuildInfo().Main.Version` in `internal/version`.
4. **Commit `LICENSE`** (already written), and add a `README.md` for owcli (install, the two ways to
   write a wiki, link to `owcli quickstart`).
5. **Ship agent-facing assets in the repo.** bossman's
   `session-catalogue-close` skill exists only in `~/.claude/skills/`; move it
   into the repo (for example `skills/session-catalogue-close/SKILL.md`) and
   document installing it.
6. ~~**Scan for secrets and local paths**~~ done 2026-10-03 (pattern scan of
   full history, all four repos). Re-run with `gitleaks git .` if one gets installed.
7. **Refresh the wiki on `main`** after the merge and rename (they change
   source that Claims point at): `owcli check`; if it fails, run an owcli
   update with the agent.
8. **Tag** the first release: `git tag -a v0.1.0 -m v0.1.0`.

## Release

The repositories already exist and are public; after each preflight:

```sh
git push origin main --tags
```

Verify from a clean environment, not this machine's checkouts:

```sh
docker run --rm golang:1.22 sh -c '
  go install github.com/Hoodoo/owcli/cmd/owcli@latest &&
  go install github.com/Hoodoo/bossman/cmd/bossman@latest &&
  go install github.com/Hoodoo/goatlassian/cmd/goatlassian@latest &&
  owcli --version && bossman --version && goatlassian --version'
```

Then commit and push kgbo-stack so `docs/install.md` is the one link to
hand someone.

## Later

- Prebuilt binaries (GoReleaser on tag) so users need no Go toolchain.
- A `kgbo` installer that reads `stack.toml` (see install guide).
