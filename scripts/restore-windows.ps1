# Restore Windows junctions into the canonical skills store.
# Canonical: %USERPROFILE%\.cursor\skills
# Also re-link any real %USERPROFILE%\.agents\skills\* into .cursor\skills,
# and remove broken junctions whose targets are missing.
$ErrorActionPreference = "Stop"
$CursorSkills = Join-Path $env:USERPROFILE ".cursor\skills"
$AgentsSkills = Join-Path $env:USERPROFILE ".agents\skills"

if (-not (Test-Path $CursorSkills -PathType Container)) {
    Write-Error "Missing canonical skills dir: $CursorSkills"
    exit 1
}

if (-not (Test-Path $AgentsSkills)) {
    New-Item -ItemType Directory -Path $AgentsSkills | Out-Null
}

Get-ChildItem $AgentsSkills -Force | ForEach-Object {
    $name = $_.Name
    $dst = Join-Path $CursorSkills $name
    $src = $_.FullName

    if ($_.LinkType -eq "Junction" -or $_.LinkType -eq "SymbolicLink") {
        $target = $null
        if ($_.Target) {
            if ($_.Target -is [array]) { $target = [string]$_.Target[0] }
            else { $target = [string]$_.Target }
        }
        if ($target -and -not (Test-Path -LiteralPath $target)) {
            Write-Host "Remove broken junction: $name -> $target"
            Remove-Item -LiteralPath $src -Force
            return
        }
        Write-Host "Skip junction: $name"
        return
    }

    if (-not (Test-Path $dst)) {
        Write-Host "Absorb: $name -> .cursor\skills"
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
    } else {
        Write-Host "Absorb (exists): replace agents copy for $name"
    }

    Remove-Item $src -Recurse -Force
    New-Item -ItemType Junction -Path $src -Target $dst | Out-Null
    Write-Host "Junction: .agents\skills\$name -> .cursor\skills\$name"
}

$skillCount = @(
    Get-ChildItem $CursorSkills -Directory |
        Where-Object { $_.Name -ne ".git" -and (Test-Path (Join-Path $_.FullName "SKILL.md")) }
).Count
Write-Host "Skills (with SKILL.md): $skillCount"
Write-Host "Canonical: $CursorSkills"
