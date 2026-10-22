#!/usr/bin/env bash
# Pushes one format's results.yaml to serialbench/data via the GitHub
# Contents API (atomic per-file, no merge conflicts from parallel legs).
# Called after each format's benchmark completes — the site rebuilds
# incrementally as data arrives.
set -euo pipefail

FMT="$1"
RUBY_VERSION="$2"
PLATFORM="$3"
RESULTS_FILE="results/runs/ci-ruby-${RUBY_VERSION}-${PLATFORM}/${FMT}/results.yaml"
DATA_TOKEN="${DATA_REPO_TOKEN:-}"

if [ -z "$DATA_TOKEN" ]; then
  echo "::warning::DATA_REPO_TOKEN not set — skipping data push"
  exit 0
fi

if [ ! -f "$RESULTS_FILE" ]; then
  echo "::warning::No results at $RESULTS_FILE — skipping"
  exit 0
fi

# The matrix start date (setup job output), so every push and rerun of one
# matrix lands in one dated directory; wall clock is only a fallback.
DATE="${DATA_RUN_DATE:-$(date -u +%Y-%m-%d)}"
TARGET_PATH="runs/${DATE}/${PLATFORM}-ruby-${RUBY_VERSION}.${FMT}.yaml"
CONTENT=$(base64 < "$RESULTS_FILE" | tr -d '\r\n')

echo "Pushing ${TARGET_PATH} to serialbench/data..."

# Try create; 409 (branch race) and 422 (exists) both retry with fresh sha
put_file() {
  # The body goes through a file: passing it as a curl argument hits the
  # ~32KB exec limit on windows/msys once a results.yaml grows ("Argument
  # list too long" -> curl never runs -> the format silently drops).
  local body
  body=$(mktemp /tmp/push-body.XXXXXX)
  if [ -n "${1:-}" ]; then
    printf '{"message": "%s (update)", "content": "%s", "sha": "%s", "branch": "main"}' \
      "${PLATFORM} ruby-${RUBY_VERSION} ${FMT}" "$CONTENT" "$1" > "$body"
  else
    printf '{"message": "%s", "content": "%s", "branch": "main"}' \
      "${PLATFORM} ruby-${RUBY_VERSION} ${FMT}" "$CONTENT" > "$body"
  fi
  curl -s -o /tmp/data-push-resp.json -w "%{http_code}" -X PUT \
    -H "Authorization: Bearer ${DATA_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/serialbench/data/contents/${TARGET_PATH}" \
    --data-binary @"$body" || echo 000
  rm -f "$body"
}

# Sha of the existing data file, empty on any failure — guarded so a dead
# pipe (curl -f, grep miss, SIGPIPE under pipefail) cannot kill the leg.
fetch_sha() {
  curl -s -H "Authorization: Bearer ${DATA_TOKEN}" \
    "https://api.github.com/repos/serialbench/data/contents/${TARGET_PATH}" \
    | grep -m1 -oE '"sha": ?"[a-f0-9]{40}"' | grep -oE '[a-f0-9]{40}' || true
}

HTTP_CODE=$(put_file "")
for TRY in 1 2 3 4 5; do
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then break; fi
  if [ "$HTTP_CODE" = "409" ] || [ "$HTTP_CODE" = "422" ]; then
    SHA=$(fetch_sha)
    [ -z "$SHA" ] && break
    echo "attempt $TRY got $HTTP_CODE — refetching sha and retrying"
    sleep $((TRY * 3))
    HTTP_CODE=$(put_file "$SHA")
  elif [ "$HTTP_CODE" = "000" ]; then
    # 000 = no HTTP response at all (connection-level blip). Retrying is
    # the only recovery — breaking here silently drops the format.
    echo "attempt $TRY got 000 (no response) — retrying"
    sleep $((TRY * 5))
    HTTP_CODE=$(put_file "")
  else
    break
  fi
done

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
  echo "Pushed ${TARGET_PATH}"
elif [ "$HTTP_CODE" = "422" ]; then
  # File exists: fetch its sha and update. 409 (sha race when the branch
  # moves between fetch and put) is retried with a fresh sha.
  UPDATE_CODE=409
  for TRY in 1 2 3; do
    SHA=$(fetch_sha)
    if [ -z "$SHA" ]; then
      echo "::warning::422 but couldn't get sha for ${TARGET_PATH}"
      break
    fi
    printf '{"message": "%s (update)", "content": "%s", "sha": "%s", "branch": "main"}' \
      "${PLATFORM} ruby-${RUBY_VERSION} ${FMT}" "$CONTENT" "${SHA}" > /tmp/push-body.json
    UPDATE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
      -H "Authorization: Bearer ${DATA_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/serialbench/data/contents/${TARGET_PATH}" \
      --data-binary @/tmp/push-body.json)
    [ "$UPDATE_CODE" = "200" ] && break
    echo "update attempt $TRY got $UPDATE_CODE — refetching sha"
    sleep 2
  done
  if [ "$UPDATE_CODE" = "200" ]; then
    echo "Updated existing ${TARGET_PATH}"
  elif [ -n "$SHA" ]; then
    echo "::warning::could not update ${TARGET_PATH} ($UPDATE_CODE)"
  fi
else
  echo "::warning::Push failed (${HTTP_CODE}): $(cat /tmp/data-push-resp.json | head -c 200)"
fi

# Trigger site rebuild (debounced by concurrency group on the .io repo)
curl -sf -X POST \
  -H "Authorization: Bearer ${DATA_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/serialbench/serialbench.github.io/dispatches" \
  -d '{"event_type": "data-updated"}' \
  && echo "Site rebuild triggered" \
  || echo "::warning::Failed to trigger site rebuild"
