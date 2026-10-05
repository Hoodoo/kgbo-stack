---
type: Guide
title: GCP Deployment
description: How deploy/gcp runs the container on one Compute Engine VM behind an HTTPS load balancer with Identity-Aware Proxy, why each resource is shaped the way it is, how the VM boots the service, and how to deploy it.
tags: [gcp, terraform, iap, deployment, operations]
verified:
  - by: owcli/v0.4.0
    at: "2026-10-05T09:32:40.353Z"
sources:
  - id: openwiki-source-a6d1c018c21915521ee86941
    resource: repo://deploy/gcp/cloud-init.yaml.tftpl
  - id: openwiki-source-d51d92c71c8f62b9fb8bae44
    resource: repo://deploy/gcp/main.tf
  - id: openwiki-source-9d6f7265a587785486b0964e
    resource: repo://deploy/gcp/variables.tf
  - id: openwiki-source-012f2c78e3b1446dfc35803f
    resource: repo://Makefile
generated: { by: "owcli/v0.4.0", at: "2026-10-05T09:32:54.546Z" }
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
Google's managed OAuth client. Health checks are TCP: an HTTP check would
get the UIs' 401, since health checkers send no IAP header. Access is
`roles/iap.httpsResourceAccessor` on each backend for every member in
`iap_members`.

## How the VM runs the service

The VM runs Container-Optimized OS with a service account that may pull
from the `kgbo` Artifact Registry repository and write logs. Its
`user-data` is `cloud-init.yaml.tftpl`, which writes two systemd units and
starts them:

- `kgbo-disk` mounts the `kgbo-data` persistent disk at `/mnt/disks/kgbo`,
  formatting it only when `blkid` finds no filesystem, and gives it to uid
  1000. The unit escapes shell variables as `$$`, because systemd expands
  `$VAR` in `Exec` lines itself.
- `kgbo` configures Docker credentials for the registry, writes
  goatlassian's `[services]` links to the public owcli and bossman URLs once,
  and runs the image with `--network host`, the disk as `/kgbo`, the UIs on
  `0.0.0.0`, their public names, and the IAP user header. `Restart=always`
  keeps it up, including while the image is not pushed yet.

The data disk has `prevent_destroy`: the data bundle lives there, so
`terraform destroy` stops at it.

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
exposed. The configuration was validated locally (`terraform validate`, the
template rendered and parsed as YAML) before its first apply.
