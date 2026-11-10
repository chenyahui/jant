# Personal fork branch workflow

This workflow applies to `chenyahui/jant`. `origin` is the fork and `upstream` is
`https://github.com/jant-me/jant.git`.

Keep fork-specific rules in this document. Leave upstream instruction files
(`AGENTS.md` and `CONTRIBUTING.md`) unchanged to reduce sync conflicts. Reference
this document by its GitHub link when starting work in this fork.

| Branch                       | Purpose                             | Allowed updates                            |
| ---------------------------- | ----------------------------------- | ------------------------------------------ |
| `main`                       | Mirror the official project         | Fast-forward from `upstream/main` only     |
| `my-release`                 | Integrate the fork's completed work | Merge commits from work branches or `main` |
| `feat/*`, `fix/*`, `chore/*` | Develop and verify changes          | Development commits                        |

Do all development, including documentation, fixes, and integration conflict
resolution, on work branches. Do not merge fork work into `main`. Do not create
standalone commits, squash merges, or rebase merges on `my-release`.

## Start work

```bash
git fetch origin
git switch my-release
git merge --ff-only origin/my-release
git switch -c feat/my-feature
```

Use `fix/<name>` for fixes and `chore/<name>` for maintenance. A branch intended
for contribution to the official project can start from `main`; its upstream PR
targets `jant-me/jant`, rather than the fork's `main`.

## Integrate completed work

Run the checks required by `AGENTS.md` on the work branch, then push it and open a
PR targeting `my-release`. Merge with **Create a merge commit**. Before opening
the PR, integrate the latest target on the work branch:

```bash
git fetch origin
git switch feat/my-feature
git merge origin/my-release
# Resolve any conflicts here, commit, and run the required checks.
git push -u origin feat/my-feature
```

If `my-release` advances while preparing the merge, return to the work branch,
merge the updated target, and verify again. Do not resolve feature integration
conflicts by editing directly on `my-release`.

## Sync the official project

Sync the remote fork through GitHub's **Sync fork** action or the CLI, then
fast-forward the local mirror:

```bash
gh repo sync chenyahui/jant --branch main
git fetch upstream
git switch main
git merge --ff-only upstream/main
```

If syncing or the fast-forward fails, stop and inspect the divergence. Do not create a
merge commit, rebase fork work onto `main`, or force-push to hide the divergence.

Bring the synchronized `main` into `my-release` through an integration branch so
any conflicts and verification stay on a work branch:

```bash
git fetch origin
git switch my-release
git merge --ff-only origin/my-release
git switch -c chore/sync-upstream-YYYY-MM-DD
git merge main
# Resolve conflicts, commit if needed, and run the required checks.
git push -u origin chore/sync-upstream-YYYY-MM-DD
```

Merge that branch into `my-release` using the completed-work process above.

## Scope of the rules

This document defines the fork's branch convention. GitHub protection is a
separate repository setting. These protections are enabled:

- `main`: lock the branch and allow fork syncing from `jant-me/jant`.
- `my-release`: require a PR, apply the restriction to administrators, and
  prohibit force pushes and deletion. Only merge commits are allowed. No
  additional approving reviewer is required for this single-maintainer fork.

The `main` branch uses a classic branch protection rule with fork syncing
enabled. The `my-release` branch uses the active
[PR-only ruleset](https://github.com/chenyahui/jant/settings/rules/26936942),
with no bypass actors. Direct pushes to either branch are blocked; synchronize
`main` through the fork sync flow and integrate work into `my-release` through
PRs.

The upstream contribution and package release instructions still describe the
official project's workflow. In this fork, local work targets `my-release`.
Creating this branch does not change the default branch, deployment triggers,
or package publishing configuration.
