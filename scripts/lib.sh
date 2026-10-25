#!/usr/bin/env bash
# Shared helpers. Source this from the other scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_DIR="$ROOT/projects"

# shellcheck disable=SC1091
set -a; source "$ROOT/config.env"; set +a

die() { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*" >&2; }

require() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is required but not installed"
  done
}

# Cloud Run service names: lowercase letters, digits and hyphens, starting with
# a letter, not ending with a hyphen, at most 49 characters.
valid_slug() {
  [[ "$1" =~ ^[a-z]([a-z0-9-]{0,47}[a-z0-9])?$ ]]
}

project_dir() { echo "$PROJECTS_DIR/$1"; }

# Read a field from a project's project.json, with a default.
# Usage: manifest <slug> <jq-path> [default]
manifest() {
  local file; file="$(project_dir "$1")/project.json"
  [[ -f "$file" ]] || die "projects/$1/project.json not found"
  jq -r --arg d "${3-}" "($2) as \$v | if \$v == null then \$d else \$v end" "$file"
}

all_projects() {
  find "$PROJECTS_DIR" -mindepth 2 -maxdepth 2 -name project.json -print0 \
    | xargs -0 -n1 dirname | xargs -n1 basename | sort
}

# Public URL a project is (or will be) served at.
project_url() {
  local slug="$1"
  if [[ -n "${DOMAIN:-}" ]]; then
    if [[ "$slug" == "www" ]]; then echo "https://$DOMAIN"; else echo "https://$slug.$DOMAIN"; fi
  else
    gcloud run services describe "$slug" --project "$GCP_PROJECT" --region "$GCP_REGION" \
      --format 'value(status.url)' 2>/dev/null || true
  fi
}
