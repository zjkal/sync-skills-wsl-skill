# sync-skills-wsl-skill

Sync Cursor agent skills between **Windows** and **WSL2** so both sides share one canonical store at `%USERPROFILE%\.cursor\skills`.

- Restores Windows junctions from `.agents\skills`
- Relinks WSL paths (`~/.cursor/skills`, `~/.agents`, `~/.claude`) to the Windows mount
- Absorbs real `.agents` copies and removes broken junctions

## Install

```bash
npx skills add zjkal/sync-skills-wsl-skill -g
```

Or install for the current project only (omit `-g`):

```bash
npx skills add zjkal/sync-skills-wsl-skill
```

After installing on Windows, ask your agent to「同步技能」or run the scripts described in [`SKILL.md`](./SKILL.md).

## Skill id

Frontmatter `name`: `sync-skills-wsl`

## Layout

```text
.
├── SKILL.md
└── scripts/
    ├── restore-windows.ps1
    ├── restore-wsl.sh
    ├── absorb-agents-skills.sh
    └── _verify-sync.sh
```

## License

MIT
