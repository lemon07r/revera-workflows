#!/usr/bin/env bash
# Enable Revera on repositories: set the four secrets and add
# .github/workflows/revera.yml (from caller.yml) on the default branch.
# Falls back to a pull request when the default branch rejects direct pushes.
#
#   ./enable.sh owner/repo [owner/repo ...]
#
# Secret values come from the environment:
#   REVERA_MODEL_BASE_URL REVERA_MODEL_API_KEY
#   REVERA_EMBEDDING_BASE_URL REVERA_EMBEDDING_API_KEY
# Re-running is safe: secrets are overwritten, an identical workflow is skipped.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SECRETS=(REVERA_MODEL_BASE_URL REVERA_MODEL_API_KEY REVERA_EMBEDDING_BASE_URL REVERA_EMBEDDING_API_KEY)
WF=.github/workflows/revera.yml

for s in "${SECRETS[@]}"; do
  [ -n "${!s:-}" ] || { echo "error: $s is not set" >&2; exit 1; }
done
[ $# -gt 0 ] || { sed -n '2,10p' "$0" >&2; exit 1; }

for repo in "$@"; do
  if [ "${repo,,}" = "lemon07r/revera-workflows" ]; then
    echo "$repo: skipped (it holds the shared workflow)" >&2
    continue
  fi
  branch=$(gh api "repos/$repo" -q .default_branch)
  for s in "${SECRETS[@]}"; do
    printf '%s' "${!s}" | gh secret set "$s" -R "$repo" >/dev/null
  done

  content=$(sed "s/__BRANCH__/$branch/" "$HERE/caller.yml")
  b64=$(printf '%s\n' "$content" | base64 -w0)
  sha=""
  if existing=$(gh api "repos/$repo/contents/$WF?ref=$branch" 2>/dev/null); then
    sha=$(jq -r .sha <<<"$existing")
    current=$(jq -r .content <<<"$existing" | base64 -d)
    if [ "$current" = "$content" ]; then
      echo "$repo: secrets set; workflow already up to date"
      continue
    fi
  fi

  args=(-X PUT "repos/$repo/contents/$WF" -f message="Add Revera PR review" -f content="$b64")
  [ -n "$sha" ] && args+=(-f sha="$sha")
  if gh api "${args[@]}" -f branch="$branch" >/dev/null 2>&1; then
    echo "$repo: secrets set; workflow committed to $branch"
  else
    head_sha=$(gh api "repos/$repo/git/ref/heads/$branch" -q .object.sha)
    gh api -X POST "repos/$repo/git/refs" -f ref=refs/heads/add-revera -f sha="$head_sha" >/dev/null 2>&1 || true
    gh api "${args[@]}" -f branch=add-revera >/dev/null
    url=$(gh pr create -R "$repo" --base "$branch" --head add-revera \
      --title "Add Revera PR review" --body "Adds the Revera workflow (lemon07r/revera-workflows).")
    echo "$repo: secrets set; $branch is protected, opened $url"
  fi
done
