---
name: semantic-versioning
description: Rules for when to increment PATCH, MINOR, or MAJOR version numbers using semantic versioning. Load when deciding how to version a code change or preparing a release.
license: MIT
metadata:
  author: Heiko Panjas
  version: "1.1"
---

# Semantic Versioning Protocol

Read this skill when you need to bump the project version. It explains when to
increment PATCH, MINOR, or MAJOR, and how to include the bump in a commit.

---

## Semantic Versioning Protocol

**AUTOMATICALLY track version changes using semantic versioning (SemVer) in the project's version manifest.**

### Locating the Version

The version lives in the project's version manifest - the file the build system reads it
from (e.g. `Cargo.toml`, `package.json`, `pyproject.toml`, `CMakeLists.txt`,
`Package.swift`). Locate it before bumping; never guess it or invent a new file.

- `AGENTS.md` usually names the manifest under its technology stack section
- If the version is recorded in more than one place, update all of them in the same commit
- If no manifest exists, ask rather than create one

### Version Format: MAJOR.MINOR.PATCH

**When to increment:**

1. **PATCH version** (X.Y.Z → X.Y.Z+1)
   - Bug fixes and minor corrections
   - Performance improvements without API changes
   - Documentation updates
   - Internal refactoring that doesn't affect the public interface
   - Example: `1.0.0` → `1.0.1`

2. **MINOR version** (X.Y.Z → X.Y+1.0)
   - New features added
   - New commands, options, or public API surface
   - New functionality that maintains backward compatibility
   - Example: `1.0.1` → `1.1.0`

3. **MAJOR version** (X.Y.Z → X+1.0.0)
   - Breaking changes to the public interface
   - Removal of features or commands
   - Changes that require user action or code updates
   - Example: `1.1.0` → `2.0.0`

### Process

After making ANY code changes:

1. Determine the type of change (fix, feature, or breaking change)
2. Update the version in the version manifest accordingly
3. Include the version change in the same commit as the code change
4. Mention version bump in commit message footer if significant

**Note:** Version changes should be included in the commit with the actual code changes, not as a separate commit.
