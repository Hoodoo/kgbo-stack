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

The image is tagged with `git describe` (`kgbo-stack:<tag>`); `make push
PROJECT=<gcp project>` sends it to that project's Artifact Registry (see
[gcp.md](gcp.md)).

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
  `OWCLI_ADDR`, `GOATLASSIAN_ADDR`). With `--network host` they are on the
  host's loopback.
- `KATA_LISTEN=host:port` also serves kata's daemon over TCP, for a hub
  that laptops join as spokes (kgbo-stack issue 0z7g).
- bossman never syncs in the container: there are no agent logs there, only
  what is shipped into the bundle.
- kata's daemon starts first; everything else starts once `kata health`
  answers, and the image sets `KATA_AUTOSTART=0` so no other kata command
  ever spawns a second daemon (one did, racing the supervisor's, before
  this).
- **Server-side clones:** when `/kgbo/server/repos.tsv` exists (`<name> <git
  url>` per line), `kgbo-repos` clones or fast-forwards each into
  `/kgbo/repos/<name>`, binds it in owcli, adopts it as the goatlassian
  project `<name>`, and builds the owcli workspaces in
  `/kgbo/server/workspaces.tsv` (`<workspace> <name>...`). It runs at start
  and every `KGBO_REPOS_EVERY` (15m; `0` disables); a failed sync is logged
  and retried without stopping the services. Public HTTPS URLs only for
  now.
- The container runs as uid 1000; the volume must be writable by it. With
  rootless podman add `--userns=keep-id` so your files map to that user.
- A normal `docker stop` takes under a second; a service that dies takes the
  container down with a non-zero exit.

## Behind a load balancer with IAP

Each UI accepts a public name and trusts a proxy header naming the
signed-in user (bossman v0.2.0, owcli v0.4.0, goatlassian v0.3.0 or later;
the Dockerfile pins the versions the image builds). Set:

| variable | example | effect |
| --- | --- | --- |
| `BOSSMAN_ADDR`, `OWCLI_ADDR`, `GOATLASSIAN_ADDR` | `0.0.0.0:7788` | listen where the load balancer reaches the UI |
| `BOSSMAN_HOST`, `OWCLI_HOST`, `GOATLASSIAN_HOST` | `bossman.example.com` | accept that name in the `Host` header |
| `KGBO_USER_HEADER` | `X-Goog-Authenticated-User-Email` | trust it as the signed-in user; refuse requests without it (401) |

goatlassian records that user as the actor of every change, and bossman
reports it at `/api/viewer`. Anyone who can reach the container directly
could send the header, so only set `KGBO_USER_HEADER` when a firewall lets
nothing but the load balancer in. The UIs answer 401 to requests without
the header, so the load balancer's health checks should be TCP checks on
the three ports; the container's own health check probes loopback and sends
the header itself. Point goatlassian's `[services]` (config.toml in its
bundle directory) at the public owcli and bossman URLs so its links work.

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
