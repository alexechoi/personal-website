terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # State is local by default. To share it (e.g. between machines), create a
  # bucket and uncomment:
  # backend "gcs" {
  #   bucket = "my-experiments-project-tfstate"
  #   prefix = "infra"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
