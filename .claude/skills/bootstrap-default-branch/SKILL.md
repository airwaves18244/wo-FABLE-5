---
name: bootstrap-default-branch
description: Fix "could not create pull request", "base branch invalid/not found", or "resource not found" errors caused by a repo having no default branch (main/master) yet. Use when a repo is genuinely empty (only a feature branch exists), when opening a PR fails because the base branch doesn't exist, or when asked to bootstrap/initialize a main branch so a PR can be opened. Works with any git remote (GitHub, GitLab, Bitbucket, local).
---

Drive this via `.claude/skills/bootstrap-default-branch/driver.sh` — it never
force-pushes and never rewrites existing history, so it's safe to run without
asking "does this branch have a main yet?" first; the script answers that
itself and no-ops if the answer is yes.

All paths below are relative to the repo root.

## The problem this solves

A brand-new repo sometimes has commits pushed only to a feature branch and no
`main`/`master` at all. Opening a PR then fails at the base-branch lookup
("Could not create pull request", "base branch invalid", GitHub UI shows
"resource not found") because there's nothing to compare against.

The tempting fixes are both traps:
- **Branch `main` off the feature branch, then PR feature→main** — GitHub
  computes zero unique commits (the feature tip is already an ancestor of
  `main`) and refuses the PR with "no commits between".
- **Force-push a rewritten `main`** — works, but force-push is a destructive,
  hard-to-reverse operation on a shared branch and needs explicit user
  authorization; don't reach for it as the default path.

The correct fix: give `main` an **orphan root commit** — a commit created in
a throwaway, unrelated git history — so it shares zero ancestry with the
feature branch. `git diff`/GitHub's compare view works fine across unrelated
histories (that's exactly how PRs with squashed/rebased/orphan branches
already work); only *merging* needs `--allow-unrelated-histories`, and PR
creation doesn't merge anything.

## Run (agent path)

```bash
# 1. Does the base branch exist at all?
.claude/skills/bootstrap-default-branch/driver.sh check <remote> main
# exit 0 + "EXISTS main -> <sha>", or exit 1 + "MISSING main"

# 2. If missing, create it as an orphan root commit. No-op (exit 0) if it
#    turns out to already exist (handles races without ever force-pushing —
#    the underlying push is a plain fast-forward-only push, so a
#    concurrently-created branch makes it fail loudly instead of clobbering).
.claude/skills/bootstrap-default-branch/driver.sh bootstrap <remote> main [readme-file]

# 3. Open the PR (uses `gh` if present, else prints the equivalent curl call).
#    No-op if a PR already exists for that head/base pair.
.claude/skills/bootstrap-default-branch/driver.sh pr <owner/repo> <head-branch> main "<title>" [body-file]
```

`<remote>` for `check`/`bootstrap` is anything `git ls-remote`/`git push`
accept: a URL, an `origin` alias from inside a clone, or a local path.
`<owner/repo>` for `pr` is what `gh --repo` accepts.

| command | what it does |
|---|---|
| `check <remote> <base>` | exit 0 if `<base>` exists on the remote, exit 1 if missing |
| `bootstrap <remote> <base> [readme]` | creates `<base>` as an orphan root commit; no-op if it already exists; never force-pushes |
| `pr <repo> <head> <base> <title> [bodyfile]` | creates the PR via `gh`, or prints the `curl` equivalent if `gh` isn't installed; no-op if one already exists |

Example, matching the exact scenario this skill exists for (repo has a
feature branch, no `main`, and a PR attempt already failed):

```bash
.claude/skills/bootstrap-default-branch/driver.sh check origin main || \
.claude/skills/bootstrap-default-branch/driver.sh bootstrap origin main
.claude/skills/bootstrap-default-branch/driver.sh pr myorg/myrepo my-feature-branch main "My feature"
```

## Test

Verified against a local bare repo standing in for a brand-new remote with
only a feature branch pushed (no `main`):

```bash
git init -q --bare /tmp/t/bare.git
# ... push a feature branch to it, then:
.claude/skills/bootstrap-default-branch/driver.sh check /tmp/t/bare.git main   # → MISSING, exit 1
.claude/skills/bootstrap-default-branch/driver.sh bootstrap /tmp/t/bare.git main
.claude/skills/bootstrap-default-branch/driver.sh check /tmp/t/bare.git main   # → EXISTS, exit 0
```

Confirmed after bootstrap: `git merge-base origin/main origin/<feature>`
finds no common ancestor (true orphan), while `git diff
origin/main..origin/<feature> --stat` still produces a clean, complete file
diff — exactly what a PR needs. Also confirmed: running `bootstrap` a second
time is a no-op, and simulating a race (another commit landing on `main`
between `check` and `bootstrap`) makes the push fail with `[rejected]
(fetch first)` instead of clobbering the existing branch.

## Gotchas

- **Don't create `main` by branching off the feature branch.** It's the
  natural-looking move and it's exactly the thing that produces "no commits
  between" — the feature branch becomes an ancestor of `main`, not a
  divergent branch from it.
- **Unrelated histories are fine for PRs, not for merges.** If someone later
  runs a local `git merge` between these branches, they'll need
  `git merge --allow-unrelated-histories`. This only matters post-merge
  cleanup, not for the PR itself.
- **The orphan commit is built in a throwaway `git init` scratch dir**, not
  in your working tree — `mktemp -d`, commit, push, delete. Your actual repo
  and any in-progress work are never touched.
- **The push is deliberately not `--force`.** If `<base>` gets created by
  someone else between `check` and `bootstrap`, the plain push fails with
  `[rejected] (fetch first)` and the script exits non-zero — that's the
  correct outcome, not a bug to work around with `-f`.

## Troubleshooting

- **`git ls-remote` hangs or fails with auth errors**: the remote needs
  credentials (SSH key / token) available to plain `git`, same as any other
  `git push` from this environment — this script doesn't do anything
  GitHub-API-specific for `check`/`bootstrap`, so whatever already lets you
  `git push` to the repo is sufficient.
- **`pr` subcommand prints a `curl` command instead of creating the PR**: no
  `gh` CLI on `PATH`. Run the printed `curl` with `GITHUB_TOKEN` set, or use
  your platform's PR-creation tool (e.g. an MCP GitHub server) with the same
  head/base/title.
- **PR creation still fails after bootstrapping**: confirm the PR's base is
  actually the branch you just created (`check <remote> <base>`) and that
  the head branch is pushed (`git ls-remote --heads <remote> <head>`) — a
  "base branch invalid" error after this point usually means a typo in the
  branch name, not the empty-repo problem.
