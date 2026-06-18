#!/usr/bin/env bash

input=$(cat)

raw_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

user=$(whoami)
dir="${raw_dir/#$HOME/\~}"

# cage sets the jail's hostname to "cage" (--hostname cage). Flag it so the bar
# makes the OS-level sandbox visible at a glance.
cage_marker=""
if [ "$(hostname 2>/dev/null)" = "cage" ] || [ -n "$CAGE" ]; then
  cage_marker=$(printf "\033[1;33m🔒 cage\033[0m \033[35m|\033[0m ")
fi

git_branch=""
if git -C "$raw_dir" --no-optional-locks rev-parse --is-inside-work-tree 2>/dev/null | grep -q true; then
  branch=$(git -C "$raw_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$raw_dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  [ -n "$branch" ] && git_branch=$(printf " \033[35m|\033[0m \033[35mgit:(%s)\033[0m" "$branch")
fi

ctx_info=""
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  if [ -n "$ctx_size" ]; then
    size_k=$((ctx_size / 1000))
    ctx_info=$(printf " \033[35m|\033[0m \033[33mctx:%s%% of %sk\033[0m" "$used_int" "$size_k")
  else
    ctx_info=$(printf " \033[35m|\033[0m \033[33mctx:%s%%\033[0m" "$used_int")
  fi
fi

printf "\033[32m%s\033[0m \033[35m|\033[0m \033[34m%s\033[0m%s \033[35m|\033[0m %s\033[36m%s\033[0m%s" \
  "$user" "$dir" "$git_branch" "$cage_marker" "$model" "$ctx_info"
