#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' 'Usage: bash scripts/my-release/publish-local.sh [--login | --deploy <ssh-key>]' \
    'Build the checked-out my-release commit for linux/amd64 and push it to TCR.' \
    'Use --login to log in with TCR_USERNAME and TCR_PASSWORD from the environment.' \
    'Set TCR_USERNAME to your TCR account ID when using --deploy.'
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi

deploy_key=""
login=false
if [[ $# -eq 1 && $1 == --login ]]; then
  login=true
  [[ -n ${TCR_USERNAME:-} ]] || fail "Export TCR_USERNAME before publishing."
  [[ -n ${TCR_PASSWORD:-} ]] || fail "Export TCR_PASSWORD before publishing."
elif [[ $# -ne 0 ]]; then
  if [[ $# -ne 2 || $1 != --deploy ]]; then
    usage >&2
    exit 2
  fi
  deploy_key="$2"
  [[ -f "$deploy_key" && -r "$deploy_key" ]] || fail "Cannot read SSH key: $deploy_key"
  [[ ${TCR_USERNAME:-} =~ ^[0-9]+$ ]] || fail "Set TCR_USERNAME to your TCR account ID."
  [[ -t 0 ]] || fail "Run --deploy in a terminal to enter the TCR password."
fi

repo_root="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
branch="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD || true)"
[[ "$branch" == my-release ]] || fail "Switch to my-release before publishing."

revision="$(git -C "$repo_root" rev-parse HEAD)"
date="$(TZ=Asia/Shanghai git -C "$repo_root" show -s --format=%cd --date=format-local:%Y%m%d "$revision")"
version="v${date}-${revision:0:7}"
registry="ccr.ccs.tencentyun.com"
image="$registry/chenyahui/jant-my-release"

docker buildx version >/dev/null 2>&1 || fail "Install Docker Buildx before publishing."

if [[ "$login" == true ]]; then
  (
    set +x
    printf '%s' "$TCR_PASSWORD" | docker login "$registry" --username "$TCR_USERNAME" --password-stdin
  )
  unset TCR_PASSWORD
fi

release_profile="jant-release"
stop_release_vm=false
push_log=""
cleanup() {
  if [[ -n "$push_log" ]]; then
    rm -f "$push_log"
  fi
  if [[ "$stop_release_vm" == true ]]; then
    colima stop "$release_profile" || printf 'Could not stop Colima profile %s.\n' "$release_profile" >&2
  fi
}
trap cleanup EXIT

# Reuse the release VM without changing the user's Docker context.
if [[ "$login" == true && $(uname -s) == Darwin &&
      -z ${DOCKER_CONTEXT:-} && -z ${DOCKER_HOST:-} &&
      $(docker context show) == colima ]]; then
  if ! colima status "$release_profile" >/dev/null 2>&1; then
    colima start "$release_profile" --activate=false
    stop_release_vm=true
  fi
  export DOCKER_CONTEXT="colima-$release_profile"
fi

printf 'Building %s:%s for linux/amd64\n' "$image" "$version"
# Use the same source as the version tag, even when the working tree has edits.
git -C "$repo_root" archive "$revision" | docker buildx build \
  --platform linux/amd64 \
  --load \
  --build-arg "JANT_BUILD_ID=$version" \
  --label 'org.opencontainers.image.title=Jant my-release' \
  --label 'org.opencontainers.image.source=https://github.com/chenyahui/jant' \
  --label "org.opencontainers.image.version=$version" \
  --label "org.opencontainers.image.revision=$revision" \
  --label 'org.opencontainers.image.licenses=AGPL-3.0-or-later' \
  --tag "$image:$version" \
  -

push_log="$(mktemp)"
docker image push "$image:$version" | tee "$push_log"
digest="$(awk -v tag="$version:" '$1 == tag && $2 == "digest:" { print $3 }' "$push_log")"
[[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]] || fail "Could not read the digest for $image:$version."

docker image tag "$image:$version" "$image:latest"
docker image push "$image:latest"
printf 'Published %s@%s\n' "$image" "$digest"

if [[ -n "$deploy_key" ]]; then
  (
    set +x
    IFS= read -rs -p 'TCR password for test deployment: ' registry_password
    printf '\n' >&2
    [[ -n "$registry_password" ]] || fail "Enter the TCR password to deploy."
    printf '%s\n%s' "$TCR_USERNAME" "$registry_password" | ssh -T -i "$deploy_key" \
      -o IdentitiesOnly=yes \
      -o ConnectTimeout=15 \
      -o ServerAliveInterval=30 \
      -o StrictHostKeyChecking=yes \
      jant@193.112.18.149 "$image@$digest"
  )
fi
