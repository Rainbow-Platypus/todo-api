#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="/opt/todo-stack"
ENV_FILE="$STACK_DIR/.env"
BACKUP_DIR="/var/backups/todo-api"
LOG_FILE="/var/log/todo-deploy.log"
HEALTH_URL="http://localhost/health"
VOLUME_NAME="todo-data"
MAX_RETRIES=15
RETRY_INTERVAL=2

log() {
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$$" "$*" | tee -a "$LOG_FILE"
}

usage() {
  echo "Usage: $0 <version>" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
NEW_VERSION="$1"

mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
cd "$STACK_DIR"

OLD_VERSION="$(grep '^APP_VERSION=' "$ENV_FILE" | cut -d= -f2)"
log "===== Deploy start: $OLD_VERSION -> $NEW_VERSION ====="

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_FILE="todos-$TIMESTAMP.db"

log "Backup SQLite -> $BACKUP_DIR/$BACKUP_FILE"
docker run --rm \
  -v "$VOLUME_NAME:/data:ro" \
  -v "$BACKUP_DIR:/backup" \
  alpine sh -c "[ -f /data/todos.db ] && cp /data/todos.db /backup/$BACKUP_FILE || echo 'no db to backup'" \
  2>&1 | tee -a "$LOG_FILE"

rollback() {
  log "!!! ROLLBACK to $OLD_VERSION !!!"
  sed -i "s/^APP_VERSION=.*/APP_VERSION=$OLD_VERSION/" "$ENV_FILE"
  if [[ -f "$BACKUP_DIR/$BACKUP_FILE" ]]; then
    log "Restore SQLite from $BACKUP_FILE"
    docker run --rm \
      -v "$VOLUME_NAME:/data" \
      -v "$BACKUP_DIR:/backup:ro" \
      alpine sh -c "cp /backup/$BACKUP_FILE /data/todos.db && chown 1000:1000 /data/todos.db" \
      2>&1 | tee -a "$LOG_FILE"
  fi
  log "Recreate app with $OLD_VERSION"
  docker compose up -d --no-deps app 2>&1 | tee -a "$LOG_FILE" || true
  log "Rollback finished."
  exit 1
}

log "Update .env -> APP_VERSION=$NEW_VERSION"
sed -i "s/^APP_VERSION=.*/APP_VERSION=$NEW_VERSION/" "$ENV_FILE"

log "Pull image..."
if ! docker compose pull app 2>&1 | tee -a "$LOG_FILE"; then
  log "Pull failed."
  rollback
fi

log "Recreate app service (no-deps)"
if ! docker compose up -d --no-deps app 2>&1 | tee -a "$LOG_FILE"; then
  log "Recreate failed."
  rollback
fi

log "Smoke test $HEALTH_URL (up to $MAX_RETRIES tries)"
for i in $(seq 1 $MAX_RETRIES); do
  if curl -sf -m 3 "$HEALTH_URL" >/dev/null; then
    log "Smoke test OK at try $i"
    log "===== Deploy success: $OLD_VERSION -> $NEW_VERSION ====="
    exit 0
  fi
  sleep "$RETRY_INTERVAL"
done

log "Smoke test failed after $MAX_RETRIES tries."
rollback
