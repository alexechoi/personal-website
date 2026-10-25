#!/usr/bin/env bash
# List every project with its type and public URL.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require jq

printf '%-24s %-8s %s\n' PROJECT TYPE URL
for slug in $(all_projects); do
  url="$(project_url "$slug")"
  printf '%-24s %-8s %s\n' "$slug" "$(manifest "$slug" .type service)" "${url:-(not deployed)}"
done
