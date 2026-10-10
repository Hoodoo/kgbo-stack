# Files

- [Container Image](container.md) - How the stack's services run in one container image, what it contains and pins, how kgbo-services supervises and health-checks them, why the bundle variables are image ENV, and how stored paths are handled inside the container.
- [GCP Deployment](gcp.md) - How deploy/gcp runs the container on one Compute Engine VM behind an HTTPS load balancer with Identity-Aware Proxy, why each resource is shaped the way it is, how the VM boots the service, and how to deploy it.
- [Local Services](local-services.md) - How the stack's four services run on a workstation, either started ad hoc by goatlassian or as systemd user units written by bin/kgbo units, and why the units record absolute paths, set KATA_AUTOSTART=0, and replace the bossman cron job.
