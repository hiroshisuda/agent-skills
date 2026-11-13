---
name: commit-messages
description: Use when writing or reviewing a git commit message, committing changes, amending a commit, or titling or merging a pull request (including PRs in a stack). Applies the user's Conventional Commits style with concise messages and references to tickets or design docs.
---

# Commit messages

Write every commit message in [Conventional Commits](https://www.conventionalcommits.org/) format, and keep it concise.

## Format

```
<type>(<optional scope>): <subject>

<optional body>

<optional footer(s)>
```

### Subject line

- **type**: one of `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`, `style`, `revert`.
- **scope**: optional; the area of the codebase affected, e.g. `feat(auth): ...`.
- **subject**: imperative mood ("add", not "added" or "adds"), lowercase start, no trailing period.
- Keep the whole line at or under 72 characters (aim for ~50).
- Breaking change: add `!` after the type or scope, e.g. `feat(api)!: drop v1 endpoints`, and explain in a `BREAKING CHANGE:` footer.

### Body

- Optional. Skip it when the subject says everything.
- When present, explain **why** the change was made, not a line-by-line account of what changed; the diff shows that.
- A few short lines or bullets at most. Wrap at 72 characters.

### Footers: references

If the work relates to a ticket, issue, or an item in documentation or a design doc, reference it. Look for one in the branch name, the conversation, or linked docs; don't invent one.

```
Refs: PROJ-123
Refs: docs/design/search.md#ranking
Closes: #42
```

If there is nothing to reference, omit the footer.

## Scope of a commit

- One logical change per commit. If the staged changes do two unrelated things, suggest splitting them.
- Check what is staged (`git diff --staged`) before writing the message so it describes the actual change.

## Pull requests

- **Titles** use the same Conventional Commits form as a commit subject; the title often becomes the commit when a PR is squash-merged. Tools that generate titles (e.g. `gh stack submit --auto`) need a follow-up `gh pr edit <number> --title "..."`.
- **Bodies** say briefly why the change was made, and carry the same `Refs:` / `Closes:` references as the commits.
- **Merging** happens only when the user asks. If they haven't said which method to use (squash, merge or rebase), ask, then pass it explicitly rather than relying on a tool's default or last-used method.

## Examples

```
feat(export): add CSV export for reports

Refs: PROJ-218
```

```
fix(parser): handle empty input without crashing

Empty files raised IndexError when reading the header row.

Closes: #87
```

```
refactor: extract retry logic into shared helper
```
