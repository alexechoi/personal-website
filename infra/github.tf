# Lets GitHub Actions in `var.github_repo` deploy without a service account key.

locals {
  github = var.github_repo == "" ? toset([]) : toset(["enabled"])
}

resource "google_service_account" "deployer" {
  for_each = local.github

  account_id   = "experiments-deployer"
  display_name = "Experiments deployer (GitHub Actions)"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "deployer" {
  for_each = var.github_repo == "" ? toset([]) : toset([
    "roles/artifactregistry.writer",
    "roles/cloudbuild.builds.editor",
    "roles/run.admin",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/storage.admin", # source uploads go to a run-sources-* bucket gcloud creates
  ])

  project = var.project_id
  role    = each.value
  member  = google_service_account.deployer["enabled"].member
}

# The deployer must be able to act as the runtime identity and the build identity.
resource "google_service_account_iam_member" "deployer_uses_runtime" {
  for_each = local.github

  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer["enabled"].member
}

resource "google_service_account_iam_member" "deployer_uses_builder" {
  for_each = local.github

  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.compute_sa}"
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deployer["enabled"].member
}

resource "google_iam_workload_identity_pool" "github" {
  for_each = local.github

  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  for_each = local.github

  workload_identity_pool_id          = google_iam_workload_identity_pool.github["enabled"].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_impersonates_deployer" {
  for_each = local.github

  service_account_id = google_service_account.deployer["enabled"].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github["enabled"].name}/attribute.repository/${var.github_repo}"
}
