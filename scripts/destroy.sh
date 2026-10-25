#!/usr/bin/env bash
# Delete a project's Cloud Run service. The folder in projects/ is left alone.
#
#   scripts/destroy.sh <slug>
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require gcloud

slug="${1:?usage: scripts/destroy.sh <slug>}"
[[ "$slug" == www ]] && die "refusing to delete the homepage"

gcloud run services delete "$slug" --project "$GCP_PROJECT" --region "$GCP_REGION" --quiet
info "deleted service '$slug'"
echo "   Remove projects/$slug too, or it will be redeployed the next time it changes."
echo "   Redeploy the homepage to drop it from the list: make deploy p=www"
