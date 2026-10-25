#!/usr/bin/env bash
# Deploy one or more projects to Cloud Run.
#
#   scripts/deploy.sh <slug> [<slug>...]   deploy the named projects
#   scripts/deploy.sh --all                deploy every project
#   scripts/deploy.sh --changed <git-ref>  deploy projects changed since <git-ref>
#
# `www` is always deployed last so its project list includes everything else.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require gcloud jq

RUNTIME_SA="experiments-runtime@${GCP_PROJECT}.iam.gserviceaccount.com"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

changed_since() {
  local base="$1" files
  # A brand-new branch (or a force push) has no usable base: deploy everything.
  if [[ "$base" =~ ^0+$ ]] || ! git -C "$ROOT" cat-file -e "$base^{commit}" 2>/dev/null; then
    all_projects; return
  fi
  files="$(git -C "$ROOT" diff --name-only "$base" HEAD)"
  {
    sed -n 's#^projects/\([^/]*\)/.*#\1#p' <<<"$files"
    # A change to the shared static runtime affects every static project.
    if grep -q '^runtime/static/' <<<"$files"; then
      for p in $(all_projects); do
        [[ "$(manifest "$p" .type service)" == static ]] && echo "$p"
      done
    fi
  } | sort -u | while read -r p; do
    # Skip projects that were deleted in this change.
    [[ -n "$p" && -f "$(project_dir "$p")/project.json" ]] && echo "$p"
  done
}

deploy_one() {
  local slug="$1" dir type build output source tmp
  dir="$(project_dir "$slug")"
  valid_slug "$slug" || die "'$slug' is not a valid Cloud Run service name"
  [[ -f "$dir/project.json" ]] || die "projects/$slug/project.json not found"

  type="$(manifest "$slug" .type service)"
  build="$(manifest "$slug" .build)"
  output="$(manifest "$slug" .output .)"
  tmp="$WORK/$slug"
  mkdir -p "$tmp"

  if [[ -n "$build" ]]; then
    info "$slug: building ($build)"
    (cd "$dir" && bash -c "$build")
  fi

  case "$type" in
    static)
      # Stage the files next to the shared nginx Dockerfile.
      cp "$ROOT"/runtime/static/* "$tmp/"
      mkdir "$tmp/site"
      (cd "$dir/$output" && tar --exclude=node_modules --exclude=.git -cf - .) | tar -xf - -C "$tmp/site"
      source="$tmp"
      ;;
    service) source="$dir" ;;
    *) die "$slug: unknown type '$type' (expected 'static' or 'service')" ;;
  esac

  local args=(
    --project "$GCP_PROJECT"
    --region "$GCP_REGION"
    --source "$source"
    --service-account "$RUNTIME_SA"
    --memory "$(manifest "$slug" .memory "$DEFAULT_MEMORY")"
    --cpu "$(manifest "$slug" .cpu "$DEFAULT_CPU")"
    --max-instances "$(manifest "$slug" .maxInstances "$DEFAULT_MAX_INSTANCES")"
    --min-instances "$(manifest "$slug" .minInstances 0)"
    --labels "managed-by=experiments,type=$type"
    --quiet
  )

  if [[ "$(manifest "$slug" .public true)" == true ]]; then
    args+=(--allow-unauthenticated)
  else
    args+=(--no-allow-unauthenticated)
  fi

  # Plain env vars, from "env": { "KEY": "value" }. Replaces whatever is set.
  jq '.env // {} | map_values(tostring)' "$dir/project.json" > "$WORK/$slug.env.json"
  args+=(--env-vars-file "$WORK/$slug.env.json")

  # Secret Manager secrets, from "secrets": { "KEY": "secret-name:version" }.
  local secrets
  secrets="$(jq -r '.secrets // {} | to_entries | map("\(.key)=\(.value)") | join(",")' "$dir/project.json")"
  [[ -n "$secrets" ]] && args+=(--set-secrets "$secrets")

  info "$slug: deploying ($type)"
  gcloud run deploy "$slug" "${args[@]}"
  info "$slug: live at $(project_url "$slug")"
}

case "${1-}" in
  "" | -h | --help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --all) mapfile -t targets < <(all_projects) ;;
  --changed) mapfile -t targets < <(changed_since "${2:?--changed needs a git ref}") ;;
  *) targets=("$@") ;;
esac

if [[ ${#targets[@]} -eq 0 ]]; then
  info "nothing to deploy"
  exit 0
fi

# Anything deployed means the homepage's project list may be stale.
deploy_www=false
others=()
for t in "${targets[@]}"; do
  if [[ "$t" == www ]]; then deploy_www=true; else others+=("$t"); fi
done
[[ ${#others[@]} -gt 0 && -f "$(project_dir www)/project.json" ]] && deploy_www=true

for t in "${others[@]}"; do deploy_one "$t"; done
if $deploy_www; then deploy_one www; fi
