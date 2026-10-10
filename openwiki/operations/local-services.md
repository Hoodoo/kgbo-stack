---
type: Guide
title: Local Services
description: How the stack's four services run on a workstation, either started ad hoc by goatlassian or as systemd user units written by bin/kgbo units, and why the units record absolute paths, set KATA_AUTOSTART=0, and replace the bossman cron job.
tags: [systemd, services, operations, kata, bossman, cron]
verified:
  - by: owcli/v0.4.0
    at: "2026-10-10T14:10:23.401Z"
sources:
  - id: openwiki-source-4295305d9bd805a055f92696
    resource: repo://bin/kgbo
  - id: openwiki-source-cea96ae8f357252ff94e036c
    resource: repo://deploy/container/Dockerfile
  - id: openwiki-source-aba0804f4b63f288f9daec3a
    resource: repo://deploy/container/kgbo-services
  - id: openwiki-source-6215ef1e20210625bdbea089
    resource: repo://docs/data-bundle.md
  - id: openwiki-source-07dce1e07e2253eab6205a2e
    resource: repo://docs/install.md
  - id: openwiki-source-1a91849fbfee35c0f5eed2a6
    resource: repo://stack.toml
generated: { by: "owcli/v0.4.0", at: "2026-10-10T14:11:10.634Z" }
---

# Local Services

On a workstation the stack runs four long-lived processes: `kata daemon`,
`owcli serve`, `bossman serve`, and `goatlassian serve`. There are two ways
to run them. `goatlassian services start` starts whichever are missing,
detached, with their output in goatlassian's logs directory. On Linux,
`bin/kgbo units` writes systemd user units so the set is started, stopped,
and logged with `systemctl --user` and `journalctl --user`. The server runs
the same processes in one container instead; see
[Container Image](container.md).

## The units bin/kgbo units writes

`bin/kgbo units` writes `kgbo.target` and one service per tool into
`~/.config/systemd/user` (`--dir` elsewhere, `--dry-run` prints them). The
services are declared in the `SERVICES` table in `bin/kgbo`:

| unit | runs |
| --- | --- |
| `kgbo-kata.service` | `kata daemon start --foreground` |
| `kgbo-owcli.service` | `owcli serve --no-open --addr 127.0.0.1:4321` |
| `kgbo-bossman.service` | `bossman serve --addr 127.0.0.1:7788 --sync-every 1h` |
| `kgbo-goatlassian.service` | `goatlassian serve --addr 127.0.0.1:7799` |

These are the same loopback addresses the container's `kgbo-services`
defaults to. Every service is `PartOf=kgbo.target` and `WantedBy=kgbo.target`,
and the target is `WantedBy=default.target`, so stopping or restarting the
target acts on all four. goatlassian `Wants=` and starts `After=` the other
three. Each service restarts on failure after five seconds and runs in the
home directory (`WorkingDirectory=%h`).

```sh
bin/kgbo units
systemctl --user daemon-reload
systemctl --user enable --now kgbo.target kgbo-kata.service kgbo-owcli.service \
  kgbo-bossman.service kgbo-goatlassian.service
systemctl --user stop kgbo.target
journalctl --user -u 'kgbo-*' -f
```

`kgbo units` only writes files; it never calls `systemctl`. It prints the
`daemon-reload` and `enable --now` line to run next.

## Why the units record absolute paths

`go install` puts owcli, bossman, and goatlassian in `$(go env GOPATH)/bin`,
while kata's installer and `make install` use `~/.local/bin`. The systemd
user manager's PATH has neither. `unit_files()` therefore looks up each tool
with `shutil.which` when the units are written, writes that absolute path
into `ExecStart`, and sets `Environment=PATH=` to the tools' directories
followed by `/usr/local/bin:/usr/bin:/bin`, because goatlassian itself runs
kata and git. A tool missing from PATH makes `kgbo units` fail rather than
write a broken unit. When a tool moves to another directory, run
`bin/kgbo units` again.

The cron line for `bossman sync` in `docs/install.md` has the same problem
and solution: it is written with `$(command -v bossman)` expanded at install
time, since cron's PATH lacks both directories as well. The provider's
`schedule` in `stack.toml` says the same.

## One kata daemon

Every unit sets `KATA_AUTOSTART=0`. A kata command that finds no daemon
otherwise starts its own, and the unit's daemon would then fail with
"already listening" (the container sets the same variable for the same
reason). Two more steps in `kgbo-kata.service` handle the cases where that
has already happened or could happen during startup:

- `ExecStartPre` runs `kata daemon stop`, so a daemon an earlier kata command
  autostarted is shut down and the unit takes over. With no daemon running,
  `kata daemon stop` succeeds, so the unit still starts.
- `ExecStartPost` polls `kata health` for up to 60 seconds. The unit counts
  as started only once the daemon answers, so goatlassian, ordered `After=`
  it, never starts against a daemon that is not up yet.

The kata daemon keys on the `KATA_HOME` string. The units take the bundle
variables from `~/.config/environment.d`, which the user manager reads at
login; see [Data Bundle](../concepts/data-bundle.md). A unit that ran without
those variables while shells had them would get a second daemon on the old
defaults.

## Scheduling bossman sync

Claude Code deletes session logs after 30 days by default, so bossman must
sync regularly. `kgbo-bossman.service` runs `bossman serve --sync-every 1h`,
which archives sessions while the service runs and replaces the hourly cron
job from `docs/install.md`. Use one or the other. The units stop when you
log out unless lingering is enabled (`loginctl enable-linger`); cron runs
regardless.

## Relation to goatlassian services start

`goatlassian services start` starts only the services that are not
reachable, so it does nothing while the units are running. If it started them
first, the units fail to bind their ports and keep retrying until those
processes are stopped. Step 6 of `docs/install.md` lists both ways to start
the services.

## Changing the units

To add a service or change an argument or address, edit `SERVICES` in
`bin/kgbo`, keep the addresses in step with goatlassian's `[services]`
configuration and the container's `kgbo-services`, and check the output with
`bin/kgbo units --dir <scratch> && systemd-analyze --user verify <scratch>/*`.
How docs and `stack.toml` are kept consistent is in
[Maintaining the Stack](../workflows/maintaining-the-stack.md).
