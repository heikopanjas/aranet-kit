---
name: git-workflow
description: Git commit message format using conventional commits, with character limits, commit types, branch workflow, and examples. Load before making a commit or reviewing git history.
license: MIT
metadata:
  author: Heiko Panjas
  version: "1.1"
---

# Git Workflow Conventions

Read this skill before making a commit. It contains the full commit message format,
character limits, conventional commit types, and examples.

---

## Commit Protocol (CRITICAL)

- **NEVER commit automatically** - always wait for explicit confirmation
- **NO co-authorship by coding agents** - never add `Co-Authored-By` trailers, `Generated with` footers, or any other attribution naming an AI coding agent
- **IF A COMMIT MESSAGE HAS A BODY, EVERY BODY LINE MUST BE A BULLET**
- **BODY BULLETS MUST START WITH `-`**
- **DO NOT write prose paragraphs in commit message bodies**

Whenever asked to commit changes:

- Stage the changes
- Write a detailed but concise commit message using conventional commits format
- If using a commit body, write it as bullet points that explain what and why
- Commit the changes

This is **CRITICAL**!

## **Commit Message Guidelines - CRITICAL**

Follow these rules to prevent VSCode terminal crashes and ensure clean git history:

**Message Format (Conventional Commits):**

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Character Limits:**

- **Subject line**: Maximum 50 characters (strict limit)
- **Body lines**: Wrap at 72 characters per line
- **Total message**: Keep under 500 characters total
- **Blank line**: Always add blank line between subject and body

**Subject Line Rules:**

- Use conventional commit types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`
- Scope is optional but recommended: `feat(api):`, `fix(build):`, `docs(readme):`
- Use imperative mood: "add feature" not "added feature"
- No period at end of subject line
- Keep concise and descriptive

**Body Rules (MANDATORY WHEN A BODY EXISTS):**

- Add blank line after subject before body
- Body text is mandatory even for simple commits
- Start every body line with `-`, except wrapped continuation lines
- Use lowercase text after each bullet marker
- Wrap each body line at 72 characters maximum
- Explain what and why, not how
- Keep it concise

**Footer Rules:**

- Use the footer only for issue references (`#123`) or `BREAKING CHANGE:` notes
- **Never add co-authorship or attribution for coding agents**: no `Co-Authored-By` trailers, no `Generated with` lines, no AI tool names

**Special Character Safety:**

- Avoid nested quotes or complex quoting
- Avoid special shell characters: `$`, `` ` ``, `!`, `\`, `|`, `&`, `;`
- Use simple punctuation only
- No emoji or unicode characters

**Best Practices:**

- **Break up large commits**: Split into smaller, focused commits with shorter messages
- **One concern per commit**: Each commit should address one specific change
- **Test before committing**: Ensure code builds and works
- **Reference issues**: Use `#123` format in footer if applicable

**Examples:**

Good:

```text
feat(api): add FooTrim function

- add trimming function to remove whitespace from
  both ends of string
- supports all encodings
```

Good (short):

```text
fix(build): correct static library output name

- keep release artifacts named consistently
```

Bad (too long):

```text
feat(api): add a new comprehensive string trimming function that handles all edge cases including UTF-8, UTF-16LE, UTF-16BE, and ANSI encodings with proper boundary checking and memory management
```

Bad (special characters):

```text
fix: update `Foo` with "nested 'quotes'" & $special chars!
```

**Invoking git commit safely:**

Each `-m` flag creates a **separate paragraph** with a blank line between it and the next. Never use one `-m` per bullet line, or every bullet ends up separated by a blank line.

Wrong (blank line between every bullet):

```text
git commit -m subject -m bullet-one -m bullet-two -m bullet-three
```

Right - put the entire body in a single `-m` with embedded newlines:

- zsh / bash: use ANSI-C quoting `$'...\n...'` so `\n` becomes a real newline
- PowerShell: use a here-string `@"...newlines..."@` passed as one argument
- Cross-shell: write the message to a temp file and use `git commit -F <file>`

The rule: subject in the first `-m`, the **whole** body in the second `-m`. Bullet lists must live inside one body paragraph.
