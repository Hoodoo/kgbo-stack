# The stack in a container

`deploy/container/` builds one image with all four tools and git. It runs
kata's daemon and the owcli, bossman, and goatlassian web UIs, with all state
in a `/kgbo` volume: the [data bundle](data-bundle.md), reached through the
home variables (a container never uses the symlink mode). It is the unit the
hosted setup runs on a VM (kata epic bct0); agents keep the tools installed
on their own machines.

```sh
make image                              # docker build; CONTAINER=podman also works
```

The image pins tool versions as build arguments (`OWCLI_VERSION`,
`BOSSMAN_VERSION`, `GOATLASSIAN_VERSION`, `KATA_VERSION` with its SHA-256,
since kata publishes no checksum file). It also carries `bin/kgbo` and
`stack.toml`, so `kgbo snapshot` and `kgbo remap` run on the server.

The bundle's variables (`KATA_HOME=/kgbo/kata` and the rest) are set with
`ENV`, so every process sees them: the services, the health check, and
anything run with `docker exec`. A process without them would use the
defaults, and kata would start a second, empty daemon there. The build runs
`kgbo env` and fails if the `ENV` lines have drifted from `stack.toml`.

## Running it

Seed the volume with a snapshot of a bundle, or start empty:

```sh
bin/kgbo snapshot /srv/kgbo             # on the machine whose state you want to show
docker run -d --name kgbo --restart unless-stopped \
  --network host -v /srv/kgbo:/kgbo kgbo-stack
```

- `kgbo-services` (the entrypoint, under `tini`) starts the four services
  and exits when any of them does, so the restart policy brings the set back
  together. `kgbo-services check` is the health check.
- The web UIs listen on loopback inside the container: bossman on 7788,
  owcli on 4321, goatlassian on 7799 (override with `BOSSMAN_ADDR`,
  `OWCLI_PORT`, `GOATLASSIAN_ADDR`). With `--network host` they are on the
  host's loopback. Serving them to other machines needs the reverse-proxy
  work in owcli#gtnc, bossman#w9jy, and oatlassian#a2zs.
- `KATA_LISTEN=host:port` also serves kata's daemon over TCP, for a hub
  that laptops join as spokes (kgbo-stack issue 0z7g).
- bossman never syncs in the container: there are no agent logs there, only
  what is shipped into the bundle.
- The container runs as uid 1000; the volume must be writable by it. With
  rootless podman add `--userns=keep-id` so your files map to that user.
- A normal `docker stop` takes under a second; a service that dies takes the
  container down with a non-zero exit.

## Paths inside the container

The bundle stores absolute repository paths from the machine it came from.
Either mount the repositories at the same paths (read-only is enough, as in
`-v /home/me/src:/home/me/src:ro`), or clone them anywhere in the container
and rewrite the stored paths there:

```sh
docker exec kgbo kgbo remap --dry-run /home/me/src /repos
docker exec kgbo kgbo remap /home/me/src /repos
```

`remap` needs owcli v0.3.0 and goatlassian v0.2.0 or later (the `relocate`
command), which the image pins. See
[moving.md](moving.md). Keeping server-side clones current is kata issue
1dhc.
