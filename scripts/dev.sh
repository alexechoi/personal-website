#!/usr/bin/env bash
# Run a project locally on http://localhost:8080.
#
#   scripts/dev.sh <slug>
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require jq

slug="${1:?usage: scripts/dev.sh <slug>}"
dir="$(project_dir "$slug")"
[[ -f "$dir/project.json" ]] || die "projects/$slug/project.json not found"

build="$(manifest "$slug" .build)"
[[ -n "$build" ]] && (cd "$dir" && bash -c "$build")

export PORT=8080
case "$(manifest "$slug" .type service)" in
  static)
    require python3
    info "serving projects/$slug/$(manifest "$slug" .output .) on http://localhost:$PORT"
    exec python3 -m http.server "$PORT" --directory "$dir/$(manifest "$slug" .output .)"
    ;;
  service)
    if [[ -f "$dir/Dockerfile" ]]; then
      require docker
      docker build -t "experiment-$slug" "$dir"
      exec docker run --rm -it -p "$PORT:$PORT" -e PORT="$PORT" "experiment-$slug"
    elif [[ -f "$dir/package.json" ]]; then
      cd "$dir" && npm install && exec npm start
    elif [[ -f "$dir/main.py" ]]; then
      cd "$dir" && python3 -m venv .venv && .venv/bin/pip install -q -r requirements.txt
      exec .venv/bin/python main.py
    else
      die "don't know how to run projects/$slug locally; start it so it listens on \$PORT ($PORT)"
    fi
    ;;
esac
