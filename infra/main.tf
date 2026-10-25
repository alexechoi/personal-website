data "google_project" "this" {}

locals {
  compute_sa = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_service" "apis" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "certificatemanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# `gcloud run deploy --source` pushes images here. Creating it up front lets us
# add cleanup policies so lots of experiments don't pile up storage costs.
resource "google_artifact_registry_repository" "source_deploy" {
  repository_id = "cloud-run-source-deploy"
  location      = var.region
  format        = "DOCKER"
  description   = "Images built by gcloud run deploy --source"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 3
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "604800s" # 7 days
    }
  }

  depends_on = [google_project_service.apis]
}

# Identity every experiment runs as. It has no project roles beyond reading
# Secret Manager secrets referenced from a project.json "secrets" block.
resource "google_service_account" "runtime" {
  account_id   = "experiments-runtime"
  display_name = "Experiments runtime"

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "runtime_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = google_service_account.runtime.member
}

# Source deploys build as the Compute Engine default service account, which
# new projects no longer give enough permissions to do so.
resource "google_project_iam_member" "builder" {
  project = var.project_id
  role    = "roles/run.builder"
  member  = "serviceAccount:${local.compute_sa}"

  depends_on = [google_project_service.apis]
}

module "domain" {
  source = "./domain"
  count  = var.domain == "" ? 0 : 1

  domain           = var.domain
  region           = var.region
  apex_service     = var.apex_service
  dns_managed_zone = var.dns_managed_zone

  depends_on = [google_project_service.apis]
}
