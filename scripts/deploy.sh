#!/usr/bin/env bash
set -euo pipefail

SHA="${SSH_ORIGINAL_COMMAND:-${1:-}}"
if ! [[ "$SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "deploy: invalid sha" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BACKUP_DIR="${BACKUP_DIR:-/root/backups}"
HEALTH_URL="${HEALTH_URL:-https://music.diegocainzos.cv/health}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"

git fetch --quiet origin main

if ! git merge-base --is-ancestor "$SHA" origin/main; then
  echo "deploy: sha not on origin/main" >&2
  exit 3
fi

if git merge-base --is-ancestor "$SHA" HEAD; then
  echo "deploy: already deployed"
  exit 0
fi

if ! git merge-base --is-ancestor HEAD "$SHA"; then
  echo "deploy: not a fast-forward" >&2
  exit 3
fi

# Backup database
mkdir -p "$BACKUP_DIR" || exit 4
docker compose --file compose.yml exec -T resolver python -c "import sqlite3; sqlite3.connect('/service/data/diegomusic.db').backup(sqlite3.connect('/service/data/.deploy-backup.db'))" || exit 4
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
docker compose --file compose.yml cp resolver:/service/data/.deploy-backup.db "$BACKUP_DIR/diegomusic-$TIMESTAMP.db" || exit 4
docker compose --file compose.yml exec -T resolver rm -f /service/data/.deploy-backup.db || exit 4

# Prune backups keeping 14 newest by name without xargs -r
while IFS= read -r file; do
  [ -n "$file" ] && rm -f "$file"
done < <(ls -1 "$BACKUP_DIR"/diegomusic-*.db 2>/dev/null | sort -r | tail -n +15 || true)

PREV=$(git rev-parse HEAD)

rollback() {
  git reset --hard --quiet "$PREV" || { echo "deploy: ROLLBACK FAILED" >&2; exit 1; }
  docker compose --file compose.yml up -d --build || { echo "deploy: ROLLBACK FAILED" >&2; exit 1; }
  echo "deploy: rolled back to $PREV"
  exit 1
}

git merge --ff-only --quiet "$SHA" || rollback
docker compose --file compose.yml config --quiet || rollback
docker compose --file compose.yml up -d --build || rollback

healthy=0
start_time=$SECONDS
while true; do
  if curl -fsS --max-time 5 "$HEALTH_URL" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  if [ "$((SECONDS - start_time))" -ge "$HEALTH_TIMEOUT" ]; then
    break
  fi
  sleep "$HEALTH_INTERVAL"
done

if [ "$healthy" -ne 1 ]; then
  rollback
fi

echo "deploy: $SHA healthy"
exit 0
