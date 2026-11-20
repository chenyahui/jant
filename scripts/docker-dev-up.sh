#!/usr/bin/env bash
set -euo pipefail
umask 077

mkdir -p .cache
work_dir=$(mktemp -d "$PWD/.cache/docker-dev.XXXXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

backup_dir="$work_dir/backup"
if [[ -n "${JANT_DEV_BACKUP_REPO:-}" ]]; then
  git clone --depth 1 --no-tags -- "$JANT_DEV_BACKUP_REPO" "$backup_dir"
else
  backup_checkout=${JANT_DEV_BACKUP_DIR:-"$PWD/../jant-backup"}
  if [[ ! -e "$backup_checkout" ]]; then
    git clone --depth 1 --no-tags -- \
      git@github.com:chenyahui/jant-backup.git "$backup_checkout"
  else
    git -C "$backup_checkout" fetch --depth 1 --no-tags origin
  fi

  mkdir "$backup_dir"
  git -C "$backup_checkout" archive refs/remotes/origin/HEAD latest scripts |
    tar -xf - -C "$backup_dir"
fi

export JANT_DEV_SEED_DIR="$work_dir/seed"
python3 "$backup_dir/scripts/restore.py" \
  --snapshot-dir "$backup_dir/latest" --output-dir "$JANT_DEV_SEED_DIR"

# Production settings may contain a GitHub token. Clear the sync configuration
# in the restored copy before the development server starts.
python3 - "$JANT_DEV_SEED_DIR/jant.sqlite" <<'PY'
import sqlite3
import sys

database = sqlite3.connect(sys.argv[1])
with database:
    database.execute("DELETE FROM site_setting WHERE key GLOB 'GITHUB_SYNC_*'")
database.close()
PY

# The private parent directory protects the seed on the host. The bind mount
# exposes only the seed so Docker's node user can read it across host UIDs.
chmod -R a+rX "$JANT_DEV_SEED_DIR"
docker compose -f compose.dev.yml up --build --exit-code-from jant
