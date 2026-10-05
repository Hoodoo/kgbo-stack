# Files

- [Container Image](container.md) - How the stack's services run in one container image, what it contains and pins, how kgbo-services supervises and health-checks them, why the bundle variables are image ENV, and how stored paths are handled inside the container.
- [GCP Deployment](gcp.md) - How deploy/gcp runs the container on one Compute Engine VM behind an HTTPS load balancer with Identity-Aware Proxy, why each resource is shaped the way it is, how the VM boots the service, and how to deploy it.
