#!/usr/bin/env bash
# Driver for the bootstrap-default-branch skill. See SKILL.md for full docs.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  driver.sh check      <remote> <base-branch>
  driver.sh bootstrap  <remote> <base-branch> [readme-file]
  driver.sh pr         <remote-url-or-owner/repo> <head-branch> <base-branch> <title> [body-file]

  check      - exit 0 if <base-branch> exists on <remote>, exit 1 if missing.
  bootstrap  - create <base-branch> on <remote> as a brand-new ORPHAN root
               commit (no shared history with anything else in the repo).
               No-op (exit 0) if the branch already exists. Never force-pushes.
  pr         - create a PR head->base via `gh`, or print the equivalent
               `curl` command if `gh` is not installed. No-op if a PR
               already exists for that head/base pair.
EOF
}

cmd="${1:-}"; [ -n "$cmd" ] || { usage; exit 2; }
shift || true

case "$cmd" in
  check)
    remote="$1"; base="$2"
    out="$(git ls-remote --heads "$remote" "$base" 2>&1)" || {
      echo "ERROR: remote unreachable or does not exist: $remote" >&2
      echo "$out" >&2
      exit 2
    }
    sha="$(printf '%s\n' "$out" | awk '{print $1}')"
    if [ -n "$sha" ]; then
      echo "EXISTS $base -> $sha"
      exit 0
    else
      echo "MISSING $base"
      exit 1
    fi
    ;;

  bootstrap)
    remote="$1"; base="$2"; readme="${3:-}"
    existing="$(git ls-remote --heads "$remote" "$base" | awk '{print $1}')"
    if [ -n "$existing" ]; then
      echo "no-op: $base already exists at $existing"
      exit 0
    fi

    scratch="$(mktemp -d)"
    trap 'rm -rf "$scratch"' EXIT
    git init -q "$scratch"
    (
      cd "$scratch"
      git config user.email "bootstrap@localhost"
      git config user.name "bootstrap-default-branch"
      if [ -n "$readme" ] && [ -f "$readme" ]; then
        cp "$readme" README.md
      else
        printf '# Repository\n' > README.md
      fi
      git add README.md
      git commit -q -m "Initialize $base branch"
    )
    root_sha="$(git -C "$scratch" rev-parse HEAD)"

    # Fails loudly (non-fast-forward) instead of clobbering if the branch
    # was created by someone else between the check above and this push.
    git -C "$scratch" push "$remote" "HEAD:refs/heads/$base"
    echo "created $base -> $root_sha (orphan root commit, no shared history)"
    ;;

  pr)
    remote="$1"; head="$2"; base="$3"; title="$4"; bodyfile="${5:-}"
    if command -v gh >/dev/null 2>&1; then
      existing="$(gh pr list --repo "$remote" --head "$head" --base "$base" --state all --json number --jq '.[0].number' 2>/dev/null || true)"
      if [ -n "$existing" ]; then
        echo "no-op: PR #$existing already exists for $head -> $base"
        exit 0
      fi
      if [ -n "$bodyfile" ]; then
        gh pr create --repo "$remote" --head "$head" --base "$base" --title "$title" --body-file "$bodyfile"
      else
        gh pr create --repo "$remote" --head "$head" --base "$base" --title "$title" --body "$title"
      fi
    else
      echo "gh CLI not found. Equivalent REST call (needs \$GITHUB_TOKEN and owner/repo, e.g. octocat/hello-world):"
      body="$title"
      [ -n "$bodyfile" ] && body="$(cat "$bodyfile")"
      cat <<EOF
curl -sS -X POST \\
  -H "Authorization: Bearer \$GITHUB_TOKEN" \\
  -H "Accept: application/vnd.github+json" \\
  "https://api.github.com/repos/$remote/pulls" \\
  -d '$(printf '%s' "{\"title\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$title" 2>/dev/null || echo "\"$title\""),\"head\":\"$head\",\"base\":\"$base\",\"body\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$body" 2>/dev/null || echo "\"$body\"")}")'
EOF
    fi
    ;;

  *)
    usage; exit 2 ;;
esac
