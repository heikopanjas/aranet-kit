---
name: recent-updates
description: Rules for maintaining the append-only Recent Updates & Decisions log in UPDATES.md, with entry format, triggers, and timestamp discipline. Load before logging a project decision, convention change, or version bump.
license: MIT
metadata:
  author: Heiko Panjas
  version: "1.0"
---

# Recent Updates & Decisions Log

Read this skill before logging a project decision, convention change, or version bump.
The log lives in `UPDATES.md` at the workspace root and records what changed, when, and why.

---

## Purpose

`UPDATES.md` is the project's institutional memory. `AGENTS.md` describes the current state of
the project's conventions; `UPDATES.md` records how it got there. Every meaningful change lands
here as a dated entry so future sessions (and humans) can reconstruct decisions and their reasoning.

## File Structure (CRITICAL)

- `UPDATES.md` contains a title, a short intro, and a `<!-- {changelog} -->` marker line
- **Everything below the marker is the user-owned log** - slopctl never overwrites it during init or merge
- **NEVER modify, move, or remove the marker line or any content above it**
- New entries go **directly below the marker**, newest first

## When to Add an Entry

Add an entry (without being asked) whenever any of these happen:

- Technology choices (build tools, languages, frameworks, dependencies)
- Directory structure or architecture decisions
- Coding conventions and style guidelines
- Naming conventions
- Build, test, or deployment procedure changes
- Version bumps (record the SemVer reasoning)
- Bug fixes and features worth remembering

## Entry Format

```markdown
### YYYY-MM-DD (vX.Y.Z, short title)

- what changed, one concern per bullet
- rationale: why the change or decision was made
- version bump: X.Y.Z to X.Y.Z+1 (PATCH - reason)
```

**Rules:**

- Heading: ISO date, then the project version and a short lowercase title in parentheses
- Add the time of day to the title when multiple entries land on the same day
- Bullets are lowercase, concise, and explain what and why (not how)
- Include a rationale bullet for decisions; include the version bump with its SemVer reasoning
- **Newest entry first**: insert at the top of the log, directly below the marker

## Append-Only Discipline (CRITICAL)

- **NEVER edit, delete, summarize, or condense existing entries**
- **NEVER reorder entries** - history stays chronological, newest first
- The log only grows; it is never compacted
- Update the `**Last updated:**` timestamp in `AGENTS.md` in the same change

## Safety Notes

- slopctl preserves the log automatically: re-running `init` skips a modified `UPDATES.md`,
  and `merge` only touches content above the marker
- Do NOT refresh `UPDATES.md` with `slopctl update --file UPDATES.md --force` - a forced
  overwrite replaces the whole file, including the log
