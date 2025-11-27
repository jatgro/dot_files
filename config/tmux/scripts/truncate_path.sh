#!/usr/bin/env bash
# Truncate a path with a middle ellipsis if it exceeds max length.
# By default, outputs path relative to HOME ("~" substitution).
# Optional: pass --git-relative to output relative to git repo root when inside a repo.
# Usage: truncate_path.sh <path> [max_length] [--git-relative]

path="$1"
max="${2:-40}" # default max length
mode_git_relative=false
if [ "$3" = "--git-relative" ]; then
  mode_git_relative=true
fi

if [ -z "$path" ]; then
  exit 0
fi

home="$HOME"

# Compute relative path
rel="$path"
if $mode_git_relative; then
  # Ensure path is a directory
  if [ -d "$path" ]; then
    toplevel=$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$toplevel" ] && [ -d "$toplevel" ]; then
      rel=$(python3 - "$path" "$toplevel" <<'PY'
import os,sys
p=sys.argv[1]
r=sys.argv[2]
try:
    print(os.path.relpath(p, r))
except Exception as e:
    print(p)
PY
)
    fi
  fi
elif [ -n "$home" ] && [[ "$path" == "$home"* ]]; then
  rel="~${path#$home}"
fi

# If within limit, return as-is
if [ ${#rel} -le $max ]; then
  echo "$rel"
  exit 0
fi

# Strategy: keep leading components and last component; collapse middle.
IFS='/' read -r -a parts <<< "$rel"

# Handle root
if [[ "$rel" == /* || "$rel" == ~* ]]; then
  leading_slash="/"
else
  leading_slash=""
fi

# If only two parts, just truncate middle chars
if [ ${#parts[@]} -le 2 ]; then
  head_chars=$(( (max - 1) / 2 ))
  tail_chars=$(( max - 1 - head_chars ))
  echo "${rel:0:head_chars}…${rel: -tail_chars}"
  exit 0
fi

first="${parts[0]}"
last="${parts[-1]}"
# Remove empty first (root)
if [ -z "$first" ]; then
  first="/"
fi

# Build progressively adding middle parts until length limit
middle_parts=()
for (( i=1; i<${#parts[@]}-1; i++ )); do
  candidate_middle_parts=("${middle_parts[@]}" "${parts[$i]}")
  candidate_path="${leading_slash}${first}/$(IFS='/'; echo "${candidate_middle_parts[*]}")/…/${last}"
  # Replace possible '//' occurrences
  candidate_path="$(echo "$candidate_path" | sed 's#//#/#g')"
  if [ ${#candidate_path} -ge $max ]; then
    break
  fi
  middle_parts=("${candidate_middle_parts[@]}")
  # Early exit if close to limit
  if [ ${#candidate_path} -ge $((max - 4)) ]; then
    break
  fi
done

if [ ${#middle_parts[@]} -eq 0 ]; then
  echo "${leading_slash}${first}…/${last}" | sed 's#//#/#g'
else
  echo "${leading_slash}${first}/$(IFS='/'; echo "${middle_parts[*]}")/…/${last}" | sed 's#//#/#g'
fi
