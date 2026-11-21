#!/usr/bin/env bash
set -euo pipefail
set +x

usage() {
  printf '%s\n' 'Usage: bash scripts/my-release/publish-local.sh [--login] [--deploy [ssh-key]]' \
    'Build the checked-out my-release commit for linux/amd64 and push it to TCR.' \
    'Use --login to log in with TCR_USERNAME and TCR_PASSWORD from the environment.' \
    'Use --deploy to update the test site with the default SSH identity or a restricted deployment key.'
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  usage
  exit 0
fi

login=false
if [[ ${1:-} == --login ]]; then
  login=true
  shift
  [[ -n ${TCR_USERNAME:-} ]] || fail "Export TCR_USERNAME before publishing."
  [[ -n ${TCR_PASSWORD:-} ]] || fail "Export TCR_PASSWORD before publishing."
fi

deploy=false
deploy_key=""
if [[ $# -ne 0 ]]; then
  if [[ $1 != --deploy || $# -gt 2 ]]; then
    usage >&2
    exit 2
  fi
  deploy=true
  if [[ $# -eq 2 ]]; then
    deploy_key="$2"
    [[ -f "$deploy_key" && -r "$deploy_key" ]] || fail "Cannot read SSH key: $deploy_key"
  fi
  [[ ${TCR_USERNAME:-} =~ ^[0-9]+$ ]] || fail "Set TCR_USERNAME to your TCR account ID."
  [[ -n ${TCR_PASSWORD:-} || -t 0 ]] || fail "Export TCR_PASSWORD or run --deploy in a terminal."
fi

repo_root="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
branch="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD || true)"
[[ "$branch" == my-release ]] || fail "Switch to my-release before publishing."

revision="$(git -C "$repo_root" rev-parse HEAD)"
date="$(TZ=Asia/Shanghai git -C "$repo_root" show -s --format=%cd --date=format-local:%Y%m%d "$revision")"
version="v${date}-${revision:0:7}"
registry="ccr.ccs.tencentyun.com"
image="$registry/chenyahui/jant-my-release"

registry_password="${TCR_PASSWORD:-}"
unset TCR_PASSWORD
docker buildx version >/dev/null 2>&1 || fail "Install Docker Buildx before publishing."

if [[ "$login" == true ]]; then
  printf '%s' "$registry_password" | docker login "$registry" --username "$TCR_USERNAME" --password-stdin
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

if [[ "$deploy" == true ]]; then
  ssh_options=(-T -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=30 -o StrictHostKeyChecking=yes)
  image_ref="$image@$digest"
  # The restricted key accepts a bare digest reference as its forced command.
  # The default login calls the same deployment script through sudo.
  if [[ -n "$deploy_key" ]]; then
    ssh_options+=(-i "$deploy_key" -o IdentitiesOnly=yes)
    deploy_command="$image_ref"
  else
    deploy_command="sudo -n /usr/local/sbin/jant-test-deploy $image_ref"
  fi

  if [[ -z "$registry_password" ]]; then
    IFS= read -rs -p 'TCR password for test deployment: ' registry_password
    printf '\n' >&2
    [[ -n "$registry_password" ]] || fail "Enter the TCR password to deploy."
  fi
  printf 'Deploying %s to jant.cyhone.com\n' "$image_ref"
  printf '%s\n%s' "$TCR_USERNAME" "$registry_password" | ssh "${ssh_options[@]}" jant@193.112.18.149 "$deploy_command"
  curl --fail --silent --show-error --retry 5 --retry-delay 5 --retry-all-errors --max-time 30 https://jant.cyhone.com/readyz
  printf '\n'
fi
