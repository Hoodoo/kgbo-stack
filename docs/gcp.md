# Hosting the stack on GCP behind IAP

`deploy/gcp/` is Terraform for one Compute Engine VM running the
[container](container.md) behind a global HTTPS load balancer with
Identity-Aware Proxy. It is phase 1 of kata epic bct0: a personal,
sign-in-protected view of the stack.

```
browser ─HTTPS─> load balancer + IAP ─HTTP─> VM (no external IP), kgbo-stack container
                 portfolio.<ip>.nip.io  ->  :7799 goatlassian
                 wiki.<ip>.nip.io       ->  :4321 owcli
                 bossman.<ip>.nip.io    ->  :7788 bossman      /kgbo = persistent disk
```

## What it creates

- **APIs:** Compute Engine, IAP, Artifact Registry.
- **Image registry:** an Artifact Registry repository `kgbo`; the VM's
  service account may pull from it and write logs.
- **Network:** a VPC `kgbo` with Private Google Access, so the VM pulls
  images without an external IP, and Cloud NAT for other egress (GitHub,
  later kata federation).
- **Firewall:** the UI ports are open only to the load balancer's ranges
  (`35.191.0.0/16`, `130.211.0.0/22`), because the UIs trust IAP's user
  header and anyone reaching them directly could forge it. SSH is open only
  to IAP's TCP forwarding range.
- **VM:** Container-Optimized OS, `e2-small`, shielded with secure boot, OS
  Login. cloud-init mounts the data disk (formatting it only when it has no
  filesystem), writes goatlassian's `[services]` links once, and runs the
  image under systemd with the reverse-proxy settings.
- **Data disk:** `kgbo-data`, 20 GB, with `prevent_destroy`: the data bundle
  lives there.
- **Load balancer:** a static address, three backends (one per UI, each with
  IAP on and a TCP health check, since the UIs answer 401 without IAP's
  header), host rules for the three nip.io names, a Google-managed
  certificate for them, and an HTTP-to-HTTPS redirect.
- **Access:** `roles/iap.httpsResourceAccessor` for `iap_members` on each
  backend.

nip.io turns `portfolio.1-2-3-4.nip.io` into `1.2.3.4`, so no domain or DNS
records are needed.

## Cost

Roughly, per month in europe-west2: the load balancer's forwarding rules
(about $18–25 for two), the e2-small VM (about $13), Cloud NAT (about $1
plus traffic), the 20 GB disk (about $2), and a little Artifact Registry
storage. About $35–40 in all; the load balancer dominates. `terraform
destroy` removes everything except the data disk, which you delete by hand
after removing its `prevent_destroy`.

## Deploying

Prerequisites: `gcloud` signed in to the account that owns the project,
Terraform, and Docker or podman.

```sh
gcloud auth login
gcloud auth application-default login          # credentials for Terraform

cd deploy/gcp
cp terraform.tfvars.example terraform.tfvars   # project, iap_members; image_tag comes next
terraform init

# 1. The registry first, so there is somewhere to push.
terraform apply -target=google_artifact_registry_repository.kgbo

# 2. The image (prints image_tag for terraform.tfvars).
cd ../.. && make push PROJECT=<project> && cd deploy/gcp

# 3. Everything else.
terraform apply
terraform output urls
```

The managed certificate provisions once the names resolve to the load
balancer, which can take up to an hour after the first apply; until then
HTTPS fails. The first visit signs you in with Google.

To roll out a new image, `make push` again, set `image_tag`, and `terraform
apply`; the VM restarts with the new metadata.

## Starting state and what is not done here

The bundle starts empty. Filling it is the next issues of the epic: the kata
hub (0z7g), server-side repository clones (1dhc), shipping bossman data
(fy8m), and backups to Cloud Storage (d0gc). Until then, copy a snapshot in
over SSH if you want something to look at:

```sh
bin/kgbo snapshot /tmp/kgbo-seed && tar -C /tmp -czf kgbo-seed.tgz kgbo-seed
gcloud compute scp kgbo-seed.tgz kgbo:/tmp --zone <zone> --tunnel-through-iap
gcloud compute ssh kgbo --zone <zone> --tunnel-through-iap   # then: stop kgbo, unpack into /mnt/disks/kgbo, start
```

Known gaps:

- goatlassian's `services` status checks the public owcli and bossman URLs
  from inside the VM, which IAP answers with a sign-in redirect, so it
  reports them as down; the links themselves work.
- kata's own web UI is not exposed.
- The VM relies on Container-Optimized OS running cloud-init on every boot
  to rewrite and start its systemd units.
