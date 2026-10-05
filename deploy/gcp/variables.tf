variable "project" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Region for the VM, its disk, the network, and the image registry."
  type        = string
  default     = "europe-west2"
}

variable "zone" {
  description = "Zone for the VM and its data disk."
  type        = string
  default     = "europe-west2-b"
}

variable "iap_members" {
  description = "Who IAP lets in, as IAM members (\"user:me@example.com\", \"group:team@example.com\")."
  type        = list(string)
}

variable "image_tag" {
  description = "Tag of the kgbo-stack image in the project's Artifact Registry (make push prints it)."
  type        = string
}

variable "machine_type" {
  description = "VM size. The services are light; e2-small is enough for one person."
  type        = string
  default     = "e2-small"
}

variable "data_disk_gb" {
  description = "Size of the persistent disk that holds the data bundle (/kgbo)."
  type        = number
  default     = 20
}

variable "iap_oauth_client_id" {
  description = "OAuth client (Web application) IAP signs people in with. Projects outside an organization need their own: Google's managed client only admits users of the same organization, and the API that created clients is shut down, so create it in the console (docs/gcp.md)."
  type        = string
}

variable "iap_oauth_client_secret" {
  description = "Secret of iap_oauth_client_id. Kept in terraform.tfvars and the state, both git-ignored."
  type        = string
  sensitive   = true
}
