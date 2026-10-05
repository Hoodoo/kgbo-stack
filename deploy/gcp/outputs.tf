output "urls" {
  description = "The three UIs, behind IAP. The certificate takes up to an hour to provision after the first apply."
  value       = { for k, h in local.hosts : k => "https://${h}" }
}

output "lb_address" {
  value = google_compute_global_address.lb.address
}

output "image" {
  description = "The image the VM runs."
  value       = local.image
}

output "ssh" {
  description = "Shell on the VM, through IAP."
  value       = "gcloud compute ssh kgbo --zone ${var.zone} --project ${var.project} --tunnel-through-iap"
}
