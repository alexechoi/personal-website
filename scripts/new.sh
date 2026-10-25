#!/usr/bin/env bash
# Scaffold a new experiment from a template.
#
#   scripts/new.sh <slug> [template]
#
# Templates live in templates/ (static, node, python). Default: static.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require jq

slug="${1-}"
template="${2:-static}"

[[ -n "$slug" ]] || die "usage: scripts/new.sh <slug> [$(ls "$ROOT/templates" | paste -sd'|' -)]"
valid_slug "$slug" || die "'$slug' must be lowercase letters, digits and hyphens, start with a letter and be at most 49 characters"
[[ -d "$ROOT/templates/$template" ]] || die "no template '$template' (have: $(ls "$ROOT/templates" | paste -sd' ' -))"

dest="$(project_dir "$slug")"
[[ -e "$dest" ]] && die "projects/$slug already exists"

cp -R "$ROOT/templates/$template" "$dest"
jq --arg slug "$slug" '.name = $slug' "$dest/project.json" > "$dest/project.json.tmp"
mv "$dest/project.json.tmp" "$dest/project.json"
grep -rl '__SLUG__' "$dest" 2>/dev/null | while read -r f; do
  sed -i.bak "s/__SLUG__/$slug/g" "$f" && rm "$f.bak"
done

info "created projects/$slug from the '$template' template"
echo "   edit:   projects/$slug"
echo "   run:    make dev p=$slug"
echo "   deploy: make deploy p=$slug"
