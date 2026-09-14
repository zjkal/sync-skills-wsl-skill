#!/usr/bin/env bash
set -euo pipefail
echo "skills -> $(readlink /root/.cursor/skills)"
echo "agents -> $(readlink /root/.agents)"
echo "claude -> $(readlink /root/.claude 2>/dev/null || echo missing)"
echo "resolved -> $(readlink -f /root/.cursor/skills)"
echo "--- skill list ---"
# DrvFS via symlink: use -L so directories are visible to find -type d
find -L /root/.cursor/skills -mindepth 1 -maxdepth 1 -type d ! -name '.git' | while read -r d; do
  [ -f "$d/SKILL.md" ] && basename "$d"
done | sort
echo "---"
test -f /root/.cursor/skills/sync-skills-wsl/SKILL.md && echo "sync-skills-wsl: OK"
win=$(find -L /mnt/c/Users/javac/.cursor/skills -mindepth 1 -maxdepth 1 -type d ! -name '.git' -exec test -f {}/SKILL.md \; -printf '%f\n' | sort | tr '\n' ',')
wslv=$(find -L /root/.cursor/skills -mindepth 1 -maxdepth 1 -type d ! -name '.git' -exec test -f {}/SKILL.md \; -printf '%f\n' | sort | tr '\n' ',')
echo "WIN=$win"
echo "WSL=$wslv"
if [ "$win" = "$wslv" ]; then echo "MATCH=yes"; else echo "MATCH=no"; fi
