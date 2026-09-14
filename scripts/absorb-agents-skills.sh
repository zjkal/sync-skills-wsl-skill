#!/usr/bin/env bash
# Absorb newly installed ~/.agents/skills into canonical ~/.cursor/skills,
# then replace each .agents entry with a Windows junction (single content copy).
# Expects WIN_USER or to be launched from restore-wsl.sh.
set -euo pipefail

detect_win_user() {
  if [[ -n "${WIN_USER:-}" ]]; then
    echo "$WIN_USER"
    return
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$here" =~ ^/mnt/c/Users/([^/]+)/ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  echo "Cannot detect Windows username. Set WIN_USER=..." >&2
  exit 1
}

WIN_USER="$(detect_win_user)"
CURSOR_SKILLS="/mnt/c/Users/$WIN_USER/.cursor/skills"
AGENTS_SKILLS="/mnt/c/Users/$WIN_USER/.agents/skills"
PS="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

if [[ ! -d "$AGENTS_SKILLS" ]]; then
  echo "No agents skills dir: $AGENTS_SKILLS"
  exit 0
fi

mkdir -p "$CURSOR_SKILLS" "$AGENTS_SKILLS"
absorbed=0

for src in "$AGENTS_SKILLS"/*; do
  [[ -e "$src" ]] || continue
  name="$(basename "$src")"
  dst="$CURSOR_SKILLS/$name"

  if [[ -L "$src" ]]; then
    echo "Skip link: $name"
    continue
  fi

  if [[ -d "$src" && ! -L "$src" ]]; then
    link_type="$("$PS" -NoProfile -Command "(Get-Item -Force 'C:\\Users\\$WIN_USER\\.agents\\skills\\$name').LinkType" 2>/dev/null | tr -d '\r' || true)"
    if [[ "$link_type" == "Junction" || "$link_type" == "SymbolicLink" ]]; then
      # Drop broken junctions
      target="$("$PS" -NoProfile -Command "\$i=Get-Item -Force 'C:\\Users\\$WIN_USER\\.agents\\skills\\$name'; if (\$i.Target) { [string]@(\$i.Target)[0] }" 2>/dev/null | tr -d '\r' || true)"
      if [[ -n "$target" && ! -e "$dst" ]]; then
        echo "Remove broken junction: $name"
        rm -rf "$src"
        continue
      fi
      echo "Skip junction: $name"
      continue
    fi

    if [[ -d "$dst" ]]; then
      echo "Absorb (cursor already has $name): replace agents copy with junction"
    else
      echo "Absorb: move $name → .cursor/skills"
      mkdir -p "$dst"
      if command -v rsync >/dev/null 2>&1; then
        rsync -a "$src/" "$dst/"
      else
        cp -a "$src/." "$dst/"
      fi
      absorbed=$((absorbed + 1))
    fi

    rm -rf "$src"
    "$PS" -NoProfile -Command "New-Item -ItemType Junction -Path 'C:\\Users\\$WIN_USER\\.agents\\skills\\$name' -Target 'C:\\Users\\$WIN_USER\\.cursor\\skills\\$name' | Out-Null"
    echo "Junction: .agents/skills/$name → .cursor/skills/$name"
  fi
done

echo "Done. Newly absorbed: $absorbed"
