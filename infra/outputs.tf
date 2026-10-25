output "github_actions_variables" {
  description = "Set these as repository variables in GitHub (Settings → Secrets and variables → Actions → Variables)."
  value = var.github_repo == "" ? null : {
    GCP_WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.github["enabled"].name
    GCP_DEPLOYER_SERVICE_ACCOUNT   = google_service_account.deployer["enabled"].email
  }
}

output "load_balancer_ip" {
  description = "IP address the domain points at."
  value       = var.domain == "" ? null : module.domain[0].ip_address
}

output "dns_records" {
  description = "DNS records to create at your DNS provider (already created if dns_managed_zone is set)."
  value       = var.domain == "" ? null : module.domain[0].dns_records
}
