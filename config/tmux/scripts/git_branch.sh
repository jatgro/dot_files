#!/usr/bin/env bash
# Echo current git branch with tmux color codes.
# - Clean: blue/green (colour39)
# - Dirty: yellow (colour214) with '*'
# - Not a repo: dim (colour238) '∅'
# Usage: git_branch.sh <path>

path="$1"
[ -z "$path" ] && exit 0

# If not a git repo, exit silently
if ! git -C "$path" rev-parse --git-dir > /dev/null 2>&1; then
  echo "#[fg=colour238]∅"
  exit 0
fi

branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$branch" = "HEAD" ]; then
  # Detached head; try tag then short sha
  branch=$(git -C "$path" describe --tags --always 2>/dev/null)
fi

# Optional: indicate dirty state
if git -C "$path" diff --quiet --ignore-submodules HEAD 2>/dev/null; then
  colour="colour39"
  dirty=""
else
  colour="colour214"
  dirty="*"
fi

if [ -n "$branch" ]; then
  echo "#[fg=${colour}]${branch}${dirty}#[default]"
fi
