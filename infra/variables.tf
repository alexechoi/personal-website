variable "project_id" {
  description = "GCP project that hosts every experiment. Should match GCP_PROJECT in config.env."
  type        = string
}

variable "region" {
  description = "Region for Cloud Run and the serverless load balancer backends. Should match GCP_REGION in config.env."
  type        = string
  default     = "europe-west2"
}

variable "github_repo" {
  description = "owner/repo allowed to deploy from GitHub Actions via Workload Identity Federation. Empty to skip CI setup."
  type        = string
  default     = ""
}

variable "domain" {
  description = "Optional root domain, e.g. example.com. Creates a load balancer serving <slug>.<domain> for every Cloud Run service and the apex for `apex_service`. Should match DOMAIN in config.env."
  type        = string
  default     = ""
}

variable "apex_service" {
  description = "Cloud Run service served at the bare domain."
  type        = string
  default     = "www"
}

variable "dns_managed_zone" {
  description = "Optional name of a Cloud DNS managed zone for `domain`. When set, the DNS records are created for you; otherwise they're printed as outputs to add at your DNS provider."
  type        = string
  default     = ""
}
