#!/usr/bin/env bash
# Restore WSL links so Cursor Remote uses the Windows canonical skills dir.
# Usage (from Windows):
#   wsl -e bash -lc "/mnt/c/Users/<win>/.cursor/skills/sync-skills-wsl/scripts/restore-wsl.sh"
# Optional: WIN_USER=javac ./restore-wsl.sh
set -euo pipefail

detect_win_user() {
  if [[ -n "${WIN_USER:-}" ]]; then
    echo "$WIN_USER"
    return
  fi
  if [[ -n "${WSL_WIN_USER:-}" ]]; then
    echo "$WSL_WIN_USER"
    return
  fi
  # Prefer the owner of the Windows skills path this script lives under.
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$here" =~ ^/mnt/c/Users/([^/]+)/ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  if [[ -n "${USERNAME:-}" && -d "/mnt/c/Users/$USERNAME" ]]; then
    echo "$USERNAME"
    return
  fi
  echo "Cannot detect Windows username. Set WIN_USER=..." >&2
  exit 1
}

WIN_USER="$(detect_win_user)"
WIN_HOME="/mnt/c/Users/$WIN_USER"
WIN_SKILLS="$WIN_HOME/.cursor/skills"
WIN_AGENTS="$WIN_HOME/.agents"
WIN_CLAUDE="$WIN_HOME/.claude"

# Linux home for this WSL distro (often /root or /home/<user>)
LINK_HOME="${LINK_HOME:-$HOME}"

link_path() {
  local target="$1"
  local source="$2"
  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    if [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
      echo "Already linked: $target"
      return 0
    fi
    rm "$target"
  elif [[ -e "$target" ]]; then
    echo "Backing up: $target -> ${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "${target}.bak.$(date +%Y%m%d%H%M%S)"
  fi

  ln -s "$source" "$target"
  echo "Linked: $target -> $source"
}

if [[ ! -d "$WIN_SKILLS" ]]; then
  echo "Missing canonical skills dir: $WIN_SKILLS" >&2
  exit 1
fi

echo "Windows user: $WIN_USER"
echo "WSL home:     $LINK_HOME"

link_path "$LINK_HOME/.cursor/skills" "$WIN_SKILLS"
link_path "$LINK_HOME/.agents" "$WIN_AGENTS"
if [[ -d "$WIN_CLAUDE" ]]; then
  link_path "$LINK_HOME/.claude" "$WIN_CLAUDE"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/absorb-agents-skills.sh" ]]; then
  chmod +x "$SCRIPT_DIR/absorb-agents-skills.sh" 2>/dev/null || true
  WIN_USER="$WIN_USER" "$SCRIPT_DIR/absorb-agents-skills.sh"
fi

# DrvFS: -L so -type d matches Windows-mounted directories
echo "Skills: $(find -L "$WIN_SKILLS" -mindepth 1 -maxdepth 1 -type d ! -name '.git' | wc -l)"
