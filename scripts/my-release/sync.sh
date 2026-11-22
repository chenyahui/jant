#!/usr/bin/env bash
set -euo pipefail

if [[ $(git branch --show-current) != my-release ]]; then
  printf '%s\n' 'Switch to my-release before syncing.' >&2
  exit 1
fi

status=$(git status --porcelain --untracked-files=all)
if [[ -n "$status" ]]; then
  printf '%s\n' 'Commit or stash your changes before syncing.' >&2
  exit 1
fi

previous=$(git rev-parse HEAD)
printf '%s\n' 'Syncing the GitHub fork from jant-me/jant...'
gh repo sync github.com/chenyahui/jant --branch main

# Fetch into local main without force so Git rejects local commits and checks other worktrees.
git fetch --atomic --no-tags origin \
  refs/heads/main:refs/heads/main \
  +refs/heads/my-release:refs/remotes/origin/my-release

git merge --ff-only origin/my-release
if ! git merge --no-edit --no-autostash main; then
  if git rev-parse --quiet --verify MERGE_HEAD >/dev/null; then
    git merge --abort
    printf '%s\n' 'Merge aborted. Resolve the conflicts on an integration branch.' >&2
  fi
  exit 1
fi

if [[ $(git rev-parse "$previous^{tree}") == "$(git rev-parse 'HEAD^{tree}')" ]]; then
  printf '%s\n' 'my-release has no file changes.'
  exit 0
fi

git --no-pager diff --stat "$previous" HEAD --
if [[ -t 0 ]] && read -r -p 'Deploy my-release to the test environment? [y/N] ' answer; then
  case "$answer" in
    [yY]|[yY][eE][sS]) exec make deploy ;;
  esac
fi
printf '%s\n' 'Deployment skipped.'
