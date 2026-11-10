# Fork branch workflow

This workflow applies to `chenyahui/jant`. `origin` is the fork and `upstream` is
`https://github.com/jant-me/jant.git`.

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
PR targeting `my-release`. Merge with **Create a merge commit**. Alternatively,
merge locally:

```bash
git fetch origin
git switch feat/my-feature
git merge origin/my-release
# Resolve any conflicts here, commit, and run the required checks.
git switch my-release
git merge --ff-only origin/my-release
git merge --no-ff feat/my-feature
git push origin my-release
```

If `my-release` advances while preparing the merge, return to the work branch,
merge the updated target, and verify again. Do not resolve feature integration
conflicts by editing directly on `my-release`.

## Sync the official project

```bash
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
```

If the fast-forward fails, stop and inspect the divergence. Do not create a
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

`AGENTS.md` defines the development convention. Git itself does not prevent
direct commits or pushes under this convention. GitHub branch protection is a
separate repository setting.

The upstream contribution and package release instructions still describe the
official project's workflow. In this fork, local work targets `my-release`.
Creating this branch does not change the default branch, deployment triggers,
or package publishing configuration.
