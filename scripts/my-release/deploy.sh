#!/usr/bin/env bash
# Installed root-owned at /usr/local/sbin/jant-test-deploy. Read a short-lived
# GHCR token from stdin; never save it in the site's environment or logs.
set -euo pipefail
umask 077

image="${1:-}"
if [[ $# -ne 1 || ! "$image" =~ ^ghcr\.io/chenyahui/jant-my-release@sha256:[a-f0-9]{64}$ ]]; then
  echo "Usage: jant-test-deploy ghcr.io/chenyahui/jant-my-release@sha256:<digest>" >&2
  exit 1
fi

cd /opt/jant-test
exec 9>/run/lock/jant-test-deploy.lock
flock -w 600 9
export IMAGE="$image"
export DOCKER_CONFIG
DOCKER_CONFIG="$(mktemp -d /run/jant-test-docker.XXXXXX)"
backup=""

cleanup() {
  local status=$?
  rm -rf -- "$DOCKER_CONFIG"
  if [[ $status -ne 0 ]]; then
    docker compose logs --tail 60 >&2 || true
    echo "Deployment failed. Backup: ${backup:-not created; existing data unchanged}." >&2
    echo "Inspect the migration and health logs before restoring a previous version." >&2
  fi
  exit "$status"
}
trap cleanup EXIT

docker login ghcr.io --username chenyahui --password-stdin
docker compose pull

# Stop writes before copying SQLite, its WAL, and local media together. Keep
# backups root-readable only; migrations can make an image-only rollback unsafe.
docker compose stop jant
backup="/opt/jant-test/backups/$(date -u +%Y%m%dT%H%M%S)-${image##*:}.tar.gz"
tar -czf "$backup" --exclude=./backups -C /opt/jant-test .

docker compose run --rm --no-deps jant-migrate

# Complete onboarding before the first public start so visitors cannot claim
# the empty site's owner account. This file is provisioned locally, not in Git.
if [[ -f bootstrap.env ]]; then
  source bootstrap.env
  printf '%s' "$BOOTSTRAP_PASSWORD" | docker compose run --rm --no-deps -T \
    jant-migrate jant setup --email "$BOOTSTRAP_EMAIL" --password-stdin \
    --site-name 'Jant 测试环境' --language zh-Hans --time-zone Asia/Shanghai
  mv bootstrap.env bootstrap.complete.env
fi

docker compose up -d --no-deps --wait --wait-timeout 120 jant
curl --fail --silent --show-error http://127.0.0.1:3000/readyz
printf '%s\n' "$image" > current-image.tmp
mv current-image.tmp current-image
printf '\nDeployed %s\n' "$image"
