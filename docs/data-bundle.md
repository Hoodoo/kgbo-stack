# The data bundle

Everything the stack keeps outside your repositories can live in one
directory, `~/kgbo` by default (`KGBO_HOME` overrides it):

```
~/kgbo/
  kata/          issues, search index, hook logs          (was ~/.kata)
  owcli/         wiki bindings, workspaces, config,        (was ~/.config/owcli
                 external wikis                              and ~/.local/share/owcli)
  bossman/       session archive and index                 (was ~/.local/share/bossman)
  goatlassian/   projects, log, metric snapshots           (was ~/.local/share/goatlassian)
```

One directory to back up, inspect, or carry to a container. The layout is
declared in [`../stack.toml`](../stack.toml) (`[bundle]` and each provider's
`home_env`, `home_default`, `bundle_dir`), and [`../bin/kgbo`](../bin/kgbo)
reads it. `bin/kgbo` needs only Python 3.11+.

Not in the bundle:

- your repositories: in-repo wikis, `.kata.toml`, `.beads/`;
- the agents' own logs in `~/.claude` and `~/.codex` (bossman copies them
  into `bossman/archive`, which is in the bundle);
- services the tools call, such as Ollama, which kata search uses for
  embeddings.

```sh
bin/kgbo homes      # where each tool's state is now, and whether it is in the bundle
```

## Two ways to point the tools at the bundle

Pick one per machine and never mix them. kata names its daemon after the
literal `KATA_HOME` path, without resolving symlinks: a process that reaches
the bundle through a symlink and one that uses the real path get two daemons
on the same database.

### Symlinks (recommended on a workstation)

```sh
kata daemon stop                       # and stop any owcli/bossman/goatlassian `serve`
bin/kgbo adopt --dry-run               # the plan; fails if anything still has files open
bin/kgbo adopt
```

`adopt` copies each tool's state into the bundle (consistently, as below),
renames the original to `<name>.pre-kgbo`, and leaves a symlink at the
default location. No variables are needed, so terminals, GUI-launched agent
apps, hooks, and cron all reach the same state, and kata keeps its daemon
socket and hook history. It refuses to run while any `*_HOME` variable of the
stack is set, and running it again does nothing.

Roll back a tool by removing its symlink and renaming `<name>.pre-kgbo`
back. Once you trust the bundle, delete the `.pre-kgbo` directories.

### Variables (containers, or state somewhere other than the defaults)

```sh
bin/kgbo env                           # KGBO_HOME, KATA_HOME, OWCLI_HOME, BOSSMAN_HOME, GOATLASSIAN_HOME
bin/kgbo snapshot ~/kgbo               # with the tools stopped: copy current state in
```

Every process that runs a tool must see the variables, or it silently uses
the old defaults (kata would start a second daemon on them):

- shells: add `eval "$(~/AISlop/kgbo-stack/bin/kgbo env)"` to `~/.profile`;
- GUI-launched apps (Claude Desktop, Codex Desktop) on Linux:
  `bin/kgbo env --plain > ~/.config/environment.d/kgbo.conf`, then log in
  again; on macOS use `launchctl setenv` for each variable;
- cron: put the `bin/kgbo env --plain` lines at the top of the crontab,
  since cron reads no profile.

Then move the old directories aside so a process that missed the variables
fails loudly instead of using stale data. owcli needs v0.2.0 or later for
`OWCLI_HOME`.

## Backup and restore

```sh
bin/kgbo snapshot ~/backups/kgbo-$(date +%F)
tar -C ~/backups -czf ~/backups/kgbo-$(date +%F).tgz kgbo-$(date +%F)
```

`snapshot` reads each tool's state wherever the tool itself would find it,
so it works before and after adopting the bundle, and while the tools run.
SQLite databases (kata's two, bossman's, goatlassian's) are copied through
SQLite's online backup API: a consistent copy that includes committed data
still in the write-ahead log, checked with `PRAGMA integrity_check`. `-wal`,
`-shm`, journal, lock, and socket files are never copied, nor kata's
`runtime/` (daemon pid files) or goatlassian's `logs/`. Everything else is
copied as is. The destination must not already hold a snapshot.

Do not back up the live directory with plain `tar` or `rsync`: a database
copied in the middle of a write, without its WAL, can come back corrupt or
missing recent changes.

To restore, stop the tools, then replace the bundle's directories (or the
default locations, without a bundle) with the snapshot's and start them
again.

## Related work

Moving repositories or machines also needs the absolute paths the tools
store rewritten (kata issue g1n5); running the services in a container on
the bundle is q7f7.
