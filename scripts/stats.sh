#!/usr/bin/env bash
# Print LiveWall project metrics via the GitHub CLI (requires `gh auth login`).
set -euo pipefail

REPO="lyndon050516/LiveWall"

echo "== Release downloads =="
if assets=$(gh api "repos/$REPO/releases" \
    --jq '.[].assets[] | "\(.name)\t\(.download_count)"' 2>/dev/null); then
  if [ -n "$assets" ]; then
    printf '%s\n' "$assets" | awk -F'\t' '{ printf "  %-40s %s\n", $1, $2; total += $2 }
                                          END { printf "  %-40s %s\n", "TOTAL", total }'
  else
    echo "  no release assets"
  fi
else
  echo "  unavailable"
fi

echo
echo "== Traffic (last 14 days) =="
if views=$(gh api "repos/$REPO/traffic/views" --jq '"\(.count) views, \(.uniques) unique"' 2>/dev/null); then
  echo "  Views:  $views"
else
  echo "  Views:  unavailable"
fi
if clones=$(gh api "repos/$REPO/traffic/clones" --jq '"\(.count) clones, \(.uniques) unique"' 2>/dev/null); then
  echo "  Clones: $clones"
else
  echo "  Clones: unavailable"
fi

echo
echo "== Repo =="
if repo=$(gh api "repos/$REPO" \
    --jq '"  Stars:    \(.stargazers_count)\n  Forks:    \(.forks_count)\n  Watchers: \(.subscribers_count)"' 2>/dev/null); then
  printf '%b\n' "$repo"
else
  echo "  unavailable"
fi
