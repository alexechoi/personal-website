#!/usr/bin/env bash
# Print a JSON list of every visible, deployed project for the homepage.
# Run as `www`'s build step, so the list is regenerated on every deploy.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require jq

# One API call for every service's URL. Without gcloud access (e.g. local
# preview) every project is listed, with a URL only if DOMAIN is set.
if services="$(gcloud run services list --project "$GCP_PROJECT" --region "$GCP_REGION" \
    --filter 'metadata.labels.managed-by=experiments' --format json 2>/dev/null)"; then
  urls="$(jq 'map({key: .metadata.name, value: .status.url}) | from_entries' <<<"$services")"
  only_deployed=true
else
  urls='{}'
  only_deployed=false
fi

for slug in $(all_projects); do
  [[ "$slug" == www ]] && continue
  [[ "$(manifest "$slug" .hidden false)" == true ]] && continue
  run_url="$(jq -r --arg s "$slug" '.[$s] // empty' <<<"$urls")"
  [[ -z "$run_url" ]] && $only_deployed && continue

  url="$run_url"
  [[ -n "${DOMAIN:-}" ]] && url="https://$slug.$DOMAIN"

  jq -c --arg slug "$slug" --arg url "$url" '{
    slug: $slug,
    name: (.name // $slug),
    description: (.description // ""),
    tags: (.tags // []),
    source: (.source // null),
    url: (if $url == "" then null else $url end)
  }' "$(project_dir "$slug")/project.json"
done | jq -s '.'
