# Moving repositories or machines

The tools store absolute paths: owcli its bindings and workspace members,
goatlassian its components, kata a `local://` alias per project. After
repositories move, or a home directory lands on a new machine under a
different path, those paths point nowhere. `bin/kgbo remap` rewrites them in
one step.

| tool | what is rewritten | what is kept |
| --- | --- | --- |
| goatlassian | `git` refs; `owcli-wiki` repository roots | each `sessions` directory, with the new one attached next to it, since past sessions ran there |
| owcli | binding keys, custom `--wiki-dir` locations, workspace member roots | wiki and workspace IDs, active selections |
| kata | the project's `local://` alias (via `kata init` at the new path, then `kata projects detach` of the old one) | issues, and the `.kata.toml` binding in the repository |
| bossman | nothing | each session's directory, which records where it ran |

Requires owcli v0.3.0 and goatlassian v0.2.0 or later, which have the
`relocate` command; `kgbo remap` skips a tool without it and
says so.

## Repositories moved on this machine

```sh
mv ~/AISlop ~/src                                   # or move them one by one
bin/kgbo remap --dry-run ~/AISlop ~/src             # what every tool would change
bin/kgbo remap ~/AISlop ~/src
```

Pass the common prefix that changed: one repository (`~/src/shop
~/work/shop`) or a directory of them. Running it twice is harmless; the
second run finds nothing to change.

A kata project whose repository has a hosted remote is bound by that remote
(`github.com/...`), so after `remap` it simply has no `local://` alias. `kata
init` rejects a remote that is a local path (such as
`/srv/git/shop.git`); `remap` then keeps that project's old alias, carries on
with the rest, and exits non-zero naming it.

## New machine

1. On the old machine, snapshot the bundle (see
   [data-bundle.md](data-bundle.md)): `bin/kgbo snapshot ~/kgbo-snapshot`.
2. On the new machine, install the tools ([install.md](install.md)), copy the
   snapshot to `~/kgbo`, and run `bin/kgbo adopt`. The default locations
   are empty there, so it only creates the symlinks.
3. Clone the repositories where you want them.
4. Rewrite the old home prefix:

   ```sh
   bin/kgbo remap --dry-run /home/me /Users/me
   bin/kgbo remap /home/me /Users/me
   ```

   Paths that do not exist yet are reported (`missing`, `has no
   .kata.toml`); owcli and goatlassian still rewrite them, kata keeps the
   old alias until the clone is there. Run `remap` again after cloning the
   rest.

Agent logs are not part of this: Claude Code and Codex keep their own
sessions under the path they ran in, and bossman's archive keeps them as
they were.

## Order matters

`remap` runs goatlassian before owcli. A wiki component goatlassian attached
before it recorded repository roots is matched by its owcli wiki ID, and a
wiki outside any workspace is identified by a hash of its path, which `owcli
relocate` changes. Run the tools by hand in the same order if you do not use
`kgbo`:

```sh
goatlassian relocate OLD NEW
owcli relocate OLD NEW
```
