# The kgbo stack on one Compute Engine VM behind an HTTPS load balancer with
# Identity-Aware Proxy. See docs/gcp.md.
#
#   browser ─HTTPS─> global LB + IAP ─HTTP─> VM (no external IP)
#                    portfolio.<ip>.nip.io   :7799 goatlassian ┐
#                    wiki.<ip>.nip.io        :4321 owcli       ├ kgbo-stack container
#                    bossman.<ip>.nip.io     :7788 bossman     ┘ /kgbo = persistent disk
#
# The UIs trust IAP's user header, so the firewall admits only the load
# balancer's ranges to their ports; the VM has no external address.

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

locals {
  services = toset(["compute.googleapis.com", "iap.googleapis.com", "artifactregistry.googleapis.com"])

  # Names come from the load balancer's address through nip.io, so no domain
  # or DNS records are needed; the managed certificate validates through them.
  ip_dashed = replace(google_compute_global_address.lb.address, ".", "-")
  hosts = {
    goatlassian = "portfolio.${local.ip_dashed}.nip.io"
    owcli       = "wiki.${local.ip_dashed}.nip.io"
    bossman     = "bossman.${local.ip_dashed}.nip.io"
  }
  ports = { goatlassian = 7799, owcli = 4321, bossman = 7788 }

  registry_host = "${var.region}-docker.pkg.dev"
  image         = "${local.registry_host}/${var.project}/kgbo/kgbo-stack:${var.image_tag}"

  # Google front ends and health checkers reach backends from these ranges.
  lb_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

resource "google_project_service" "apis" {
  for_each           = local.services
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------- image

resource "google_artifact_registry_repository" "kgbo" {
  location      = var.region
  repository_id = "kgbo"
  format        = "DOCKER"
  description   = "kgbo-stack container images"
  depends_on    = [google_project_service.apis]
}

resource "google_service_account" "vm" {
  account_id   = "kgbo-vm"
  display_name = "kgbo stack VM"
}

resource "google_artifact_registry_repository_iam_member" "vm_pull" {
  location   = google_artifact_registry_repository.kgbo.location
  repository = google_artifact_registry_repository.kgbo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_logs" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# -------------------------------------------------------------- network

resource "google_compute_network" "kgbo" {
  name                    = "kgbo"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "kgbo" {
  name                     = "kgbo"
  network                  = google_compute_network.kgbo.id
  region                   = var.region
  ip_cidr_range            = "10.42.0.0/24"
  private_ip_google_access = true # pull from Artifact Registry without an external IP
}

# Egress for the VM (GitHub clones, kata federation) without an external IP.
resource "google_compute_router" "kgbo" {
  name    = "kgbo"
  network = google_compute_network.kgbo.id
  region  = var.region
}

resource "google_compute_router_nat" "kgbo" {
  name                               = "kgbo"
  router                             = google_compute_router.kgbo.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "lb_to_uis" {
  name          = "kgbo-lb-to-uis"
  network       = google_compute_network.kgbo.id
  source_ranges = local.lb_ranges
  target_tags   = ["kgbo"]
  allow {
    protocol = "tcp"
    ports    = [for p in values(local.ports) : tostring(p)]
  }
}

# SSH only through IAP TCP forwarding: gcloud compute ssh kgbo --tunnel-through-iap
resource "google_compute_firewall" "iap_ssh" {
  name          = "kgbo-iap-ssh"
  network       = google_compute_network.kgbo.id
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["kgbo"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ------------------------------------------------------------------- VM

resource "google_compute_disk" "data" {
  name = "kgbo-data"
  zone = var.zone
  type = "pd-balanced"
  size = var.data_disk_gb
  lifecycle {
    prevent_destroy = true # the data bundle lives here
  }
}

resource "google_compute_instance" "kgbo" {
  name         = "kgbo"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["kgbo"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 10
    }
  }

  attached_disk {
    source      = google_compute_disk.data.id
    device_name = "kgbo-data"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.kgbo.id
    # no access_config: no external IP
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    enable-oslogin = "TRUE"
    user-data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      registry_host    = local.registry_host
      image            = local.image
      goatlassian_host = local.hosts.goatlassian
      owcli_host       = local.hosts.owcli
      bossman_host     = local.hosts.bossman
    })
  }

  allow_stopping_for_update = true
  depends_on                = [google_artifact_registry_repository_iam_member.vm_pull]
}

resource "google_compute_instance_group" "kgbo" {
  name      = "kgbo"
  zone      = var.zone
  instances = [google_compute_instance.kgbo.id]
  dynamic "named_port" {
    for_each = local.ports
    content {
      name = named_port.key
      port = named_port.value
    }
  }
}

# ------------------------------------------------------- load balancer

resource "google_compute_global_address" "lb" {
  name       = "kgbo-lb"
  depends_on = [google_project_service.apis]
}

# TCP checks: the UIs answer 401 to anything without IAP's user header.
resource "google_compute_health_check" "ui" {
  for_each = local.ports
  name     = "kgbo-${each.key}"
  tcp_health_check {
    port = each.value
  }
}

resource "google_compute_backend_service" "ui" {
  for_each              = local.ports
  name                  = "kgbo-${each.key}"
  protocol              = "HTTP"
  port_name             = each.key
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 60
  health_checks         = [google_compute_health_check.ui[each.key].id]
  backend {
    group = google_compute_instance_group.kgbo.id
  }
  iap {
    enabled = true
  }
  depends_on = [google_project_service.apis]
}

resource "google_iap_web_backend_service_iam_member" "access" {
  for_each = {
    for pair in setproduct(keys(local.ports), var.iap_members) : "${pair[0]} ${pair[1]}" => {
      service = pair[0]
      member  = pair[1]
    }
  }
  web_backend_service = google_compute_backend_service.ui[each.value.service].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value.member
}

resource "google_compute_url_map" "https" {
  name            = "kgbo"
  default_service = google_compute_backend_service.ui["goatlassian"].id
  dynamic "host_rule" {
    for_each = local.hosts
    content {
      hosts        = [host_rule.value]
      path_matcher = host_rule.key
    }
  }
  dynamic "path_matcher" {
    for_each = local.hosts
    content {
      name            = path_matcher.key
      default_service = google_compute_backend_service.ui[path_matcher.key].id
    }
  }
}

resource "google_compute_managed_ssl_certificate" "kgbo" {
  name = "kgbo"
  managed {
    domains = values(local.hosts)
  }
}

resource "google_compute_target_https_proxy" "kgbo" {
  name             = "kgbo"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.kgbo.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "kgbo-https"
  target                = google_compute_target_https_proxy.kgbo.id
  ip_address            = google_compute_global_address.lb.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Plain HTTP only redirects to HTTPS.
resource "google_compute_url_map" "redirect" {
  name = "kgbo-redirect"
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "kgbo-redirect"
  url_map = google_compute_url_map.redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "kgbo-http"
  target                = google_compute_target_http_proxy.redirect.id
  ip_address            = google_compute_global_address.lb.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
