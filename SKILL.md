---
name: sync-skills-wsl
description: >-
  Sync Cursor agent skills between Windows and WSL2 so both sides share one
  canonical store at %USERPROFILE%\.cursor\skills. Restores Windows junctions
  from .agents\skills, relinks WSL paths (/root/.cursor/skills, .agents, .claude)
  to the Windows mount, absorbs real .agents copies, and removes broken
  junctions. Use when the user asks to 同步技能, sync skills, restore skills,
  relink WSL skills, Windows/WSL skill 目录, or after installing/deleting skills
  on one OS and needing the other side to match.
---

# Sync skills: Windows ↔ WSL2

**Canonical store (single source of truth):** `%USERPROFILE%\.cursor\skills`  
WSL and `.agents\skills` only link/junction into that folder — never keep a second real copy.

## When the user says things like

- 「同步技能」「同步一下 skills」
- 「restore / relink WSL skills」
- 「Windows 和 WSL 技能目录对齐」
- 刚在一侧增删 skill，要另一侧立刻一致

→ Run the full sync workflow below. Do not improvise a copy/rsync of the whole tree unless the scripts fail.

## Full sync workflow (default)

Run from **Windows** (PowerShell / Cursor on Windows). Execute both steps in order.

### 0) Resolve this skill’s install path

`npx skills add` may place the skill under `.agents\skills` or `.cursor\skills`. Resolve once, then reuse:

```powershell
$SkillRoot = @(
  "$env:USERPROFILE\.cursor\skills\sync-skills-wsl",
  "$env:USERPROFILE\.agents\skills\sync-skills-wsl"
) | Where-Object { Test-Path "$_\scripts\restore-windows.ps1" } | Select-Object -First 1
if (-not $SkillRoot) { throw "sync-skills-wsl not found under .cursor\skills or .agents\skills" }
```

### 1) Windows junctions

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$SkillRoot\scripts\restore-windows.ps1"
```

What it does:

- Ensures `%USERPROFILE%\.agents\skills` exists
- For each **real** folder under `.agents\skills` (not already a junction): copy into `.cursor\skills` if missing, then replace the agents entry with a **junction** → `.cursor\skills\<name>`
- Skips entries that are already junctions/symlinks
- Removes **broken** junctions whose target no longer exists

### 2) WSL symlinks

```powershell
$drive = $SkillRoot.Substring(0, 1).ToLower()
$unix = ($SkillRoot -replace '\\', '/') -replace '^[A-Za-z]:', "/mnt/$drive"
wsl -e bash -lc "$unix/scripts/restore-wsl.sh"
```

If `USERNAME` / profile folder name mismatches, set `WIN_USER` inside WSL or pass it when calling the script.

What it does:

- `~/.cursor/skills` → `/mnt/c/Users/<win>/.cursor/skills`
- `~/.agents` → `/mnt/c/Users/<win>/.agents`
- `~/.claude` → `/mnt/c/Users/<win>/.claude` (only if that Windows dir exists)
- Existing different targets: back up to `*.bak.<timestamp>` then relink
- Then runs `absorb-agents-skills.sh` (same absorb/junction logic from inside WSL)

### 3) Report to the user

After both steps, briefly confirm:

- Canonical path and skill count (dirs under `.cursor\skills`, excluding `.git` and this skill’s non-skill noise if any — count skill folders that contain `SKILL.md`)
- WSL link targets (`readlink` / “Already linked”)
- Any broken junctions removed or absorb actions

## Partial runs

| User intent | Run |
|---|---|
| Only fix Windows `.agents` junctions | Step 1 only |
| Only fix WSL links | Step 2 only |
| Just deleted skills, clean dangling links | Step 1 (broken-junction cleanup) + Step 2 |

## Model (mental picture)

```text
Windows:  %USERPROFILE%\.cursor\skills     ← canonical content
          %USERPROFILE%\.agents\skills\*   ← junctions → cursor\skills\*

WSL:      ~/.cursor/skills  →  /mnt/c/Users/<win>/.cursor/skills
          ~/.agents         →  /mnt/c/Users/<win>/.agents
          ~/.claude         →  /mnt/c/Users/<win>/.claude   (optional)
```

## Do / Don’t

- **Do** treat `.cursor\skills` as the only place to add/edit skill files
- **Do** re-run this sync after installing skills into `.agents\skills` or deleting skills from `.cursor\skills`
- **Don’t** `cp -r` a full second tree into WSL home
- **Don’t** create skills under `~/.cursor/skills-cursor/` (Cursor built-ins)
- **Don’t** leave real duplicates in both `.agents\skills` and `.cursor\skills`

## Legacy scripts

Older copies may still exist at:

- `~/.cursor/skills/restore-skills.ps1`
- `~/.cursor/skills/restore-skills.sh`
- `~/.cursor/skills/absorb-agents-skills.sh`

Prefer **this skill’s** `scripts/` (portable paths). If legacy scripts are present and user asks to run “那个 ps1”, either is fine; then still run the WSL step.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `wsl` not found / fails | User must enable WSL; stop and report |
| Missing `/mnt/c/Users/<win>/.cursor/skills` | Confirm Windows path; fix `WIN_USER` in env or script args |
| WSL home is not `/root` | `restore-wsl.sh` uses `$HOME` — run inside the intended distro (`wsl -d <name> ...` if needed) |
| Junction create fails | Run PowerShell outside a restricted sandbox; need filesystem permission on `%USERPROFILE%` |
| Skill count mismatch Win vs WSL | Re-run full sync; verify WSL path is a symlink to `/mnt/c/...`, not a real dir |

## Scripts

| Script | Role |
|---|---|
| [scripts/restore-windows.ps1](scripts/restore-windows.ps1) | Absorb + junctions + broken cleanup |
| [scripts/restore-wsl.sh](scripts/restore-wsl.sh) | WSL symlinks + absorb |
| [scripts/absorb-agents-skills.sh](scripts/absorb-agents-skills.sh) | WSL-side absorb via `powershell.exe` junctions |
