---
type: Guide
title: GCP Deployment
description: How deploy/gcp runs the container on one Compute Engine VM behind an HTTPS load balancer with Identity-Aware Proxy, why each resource is shaped the way it is, how the VM boots the service, and how to deploy it.
tags: [gcp, terraform, iap, deployment, operations]
verified:
  - by: owcli/v0.4.0
    at: "2026-10-05T10:41:43.869Z"
sources:
  - id: openwiki-source-a6d1c018c21915521ee86941
    resource: repo://deploy/gcp/cloud-init.yaml.tftpl
  - id: openwiki-source-d51d92c71c8f62b9fb8bae44
    resource: repo://deploy/gcp/main.tf
  - id: openwiki-source-9d6f7265a587785486b0964e
    resource: repo://deploy/gcp/variables.tf
  - id: openwiki-source-a9ebfd4901730d787b51d9c8
    resource: repo://docs/gcp.md
  - id: openwiki-source-012f2c78e3b1446dfc35803f
    resource: repo://Makefile
generated: { by: "owcli/v0.4.0", at: "2026-10-05T10:41:44.012Z" }
---

# GCP Deployment

`deploy/gcp/` is Terraform (google provider, pinned in
`.terraform.lock.hcl`) that hosts the [Container Image](container.md) on one
Compute Engine VM behind a global HTTPS load balancer with Identity-Aware
Proxy. It is phase 1 of the hosted-stack epic: a personal view of the stack
behind Google sign-in. `docs/gcp.md` is the operator guide, with costs.

## Shape

Each UI gets its own host name and load balancer backend: goatlassian at
`portfolio.<ip>.nip.io` (port 7799), owcli at `wiki.<ip>.nip.io` (4321), and
bossman at `bossman.<ip>.nip.io` (7788). The names derive from the load
balancer's static address through nip.io, so no domain is needed and the
Google-managed certificate can validate them. Host-based routing is required
because the UIs serve from `/` and cannot share one host under path
prefixes. The URL map's default service is goatlassian, and plain HTTP only
redirects to HTTPS.

## Why the network is closed

The UIs run with `KGBO_USER_HEADER=X-Goog-Authenticated-User-Email`: they
trust that header as the signed-in user and refuse requests without it.
Anyone who could reach the UI ports directly could forge the header, so:

- the VM has no external address (no `access_config`);
- the only firewall rule to the UI ports admits Google's load balancer and
  health-check ranges (`35.191.0.0/16`, `130.211.0.0/22`);
- SSH is admitted only from IAP's TCP forwarding range, with OS Login.

The subnet has Private Google Access so the VM pulls from Artifact Registry
without an external address, and Cloud NAT gives it other egress (GitHub,
later kata federation).

## Load balancer and IAP

Each backend service is `EXTERNAL_MANAGED`, points at an unmanaged instance
group whose named ports map each UI to its port, and has IAP enabled with
the project's own OAuth client (`iap_oauth_client_id`,
`iap_oauth_client_secret`). Google's managed client only admits users of the
project's Google Workspace organization, so in a personal project without
one, IAP answered every request with a 502 ("Empty Google Account OAuth
client ID(s)/secret(s)"). The API that created OAuth clients for IAP is shut
down, so the client is made by hand in Google Auth Platform (external
audience, testing status with the members as test users, a Web application
client whose redirect URI is IAP's `handleRedirect` for that client ID);
`docs/gcp.md` lists the steps. Health checks are TCP: an HTTP check would
get the UIs' 401, since health checkers send no IAP header. Access is
`roles/iap.httpsResourceAccessor` on each backend for every member in
`iap_members`.

## How the VM runs the service

The VM runs Container-Optimized OS with a service account that may pull
from the `kgbo` Artifact Registry repository and write logs. Its
`user-data` is `cloud-init.yaml.tftpl`, which writes two scripts, a config
file, and three systemd units, and starts the units:

- `kgbo-disk` runs `/etc/kgbo/mount-disk.sh`: it mounts the `kgbo-data`
  persistent disk at `/mnt/disks/kgbo`, formatting it only when `blkid`
  finds no filesystem, and gives it to uid 1000.
- `kgbo-firewall` runs `/etc/kgbo/firewall.sh`. Container-Optimized OS has
  its own host firewall whose INPUT policy drops everything but SSH, which
  left every backend unhealthy on the first deploy; the script inserts
  rules admitting the load balancer ranges to the UI ports, idempotently
  (`iptables -C` before `-I`).
- `kgbo` configures Docker credentials for the registry, copies
  `/etc/kgbo/goatlassian-config.toml` (goatlassian's `[services]` links to
  the public owcli and bossman URLs) into the bundle when goatlassian has no
  config yet, and runs the image with `--network host`, the disk as
  `/kgbo`, the UIs on `0.0.0.0`, their public names, and the IAP user
  header. `Restart=always` keeps it up, including while the image is not
  pushed yet.

Shell logic lives in the scripts and the config is written by cloud-init,
not built in `Exec` lines: systemd rewrites `$` and backslash escapes there,
and an escaped `printf` once wrote goatlassian's config without its quotes,
which crash-looped the container.

The data disk has `prevent_destroy`: the data bundle lives there, so
`terraform destroy` stops at it.

## Repositories

The `repos` variable (name => git URL) and `workspaces` (name => repository
names) choose what the server clones and how owcli groups it; the defaults
are the four public stack repositories in a `kgbo-stack` workspace. Terraform
renders them into `/etc/kgbo/repos.tsv` and `/etc/kgbo/workspaces.tsv`, and
the `kgbo` unit copies both into `/mnt/disks/kgbo/server/` on every start
(Terraform owns them, unlike goatlassian's config, which is only seeded).
The container's `kgbo-repos` does the cloning and registration (see
[Container Image](container.md)). Changing the lists takes an apply and a
VM reset, since cloud-init writes the files at boot. Only public HTTPS URLs
work so far.

## Deploying

The registry must exist before the image can be pushed, so the first deploy
is three steps: `terraform apply -target=google_artifact_registry_repository.kgbo`,
then `make push PROJECT=<id>` (which logs in with a gcloud access token,
pushes `kgbo-stack:<git describe>`, and prints the `image_tag`), then a full
`terraform apply`. Variables are `project`, `iap_members`, and `image_tag`,
with defaults for region (`europe-west2`), zone, machine type (`e2-small`),
and disk size (20 GB). Outputs are the three URLs, the load balancer
address, the image, and an IAP SSH command. The managed certificate can
take up to an hour after the first apply.

## Known gaps

The bundle starts empty until the kata hub, server-side clones, bossman
shipping, and backups exist. goatlassian's services status probes the
public URLs from inside the VM and gets IAP's sign-in redirect, so it shows
owcli and bossman as down although the links work. kata's own web UI is not
exposed.

## First deploy

Applied to a personal project, all three backends turned healthy within
about a minute of a cold VM reset, the managed certificate became active
within minutes, HTTP redirected to HTTPS, and each name redirected to
Google sign-in with the project's OAuth client; a request carrying a
forged IAP user header from outside was redirected to sign-in as well.
Signing in failed with "Access blocked: This app's request is invalid"
until the client's single redirect URI matched the `redirect_uri` IAP sends
exactly, full client ID included; after that, browser sign-in reached the
UIs.
