---
name: branching
description: Use when creating a new git branch or starting work on a feature or fix, when naming a branch, or when bringing an existing branch up to date with main.
---

# Branching

## Naming

A branch takes its name from the feature or change it adds:

- lowercase kebab-case, short and descriptive: `csv-export`, `fix-empty-input-crash`
- if there is a ticket, it may be prefixed: `proj-218-csv-export`
- no personal names or dates

In cloud sessions, a hook enforces this. It blocks `git switch -c`, `git checkout -b`, `git branch <name>`, `gh stack init`, `gh stack add`, and `git push` when the branch they create or push breaks the convention, including the `claude/...` branch the session assigns. Rename an unpushed branch with `git branch -m <new-name>` before the first push.

## Never work on main

Don't commit to, rewrite, push, or edit files on `main`, `master`, or the repository's default branch. Create a feature branch before the first change, even a small one, and open a pull request from it.

In every session, a hook enforces this. It blocks `git commit`, `merge` (except `--ff-only`), `rebase`, `cherry-pick`, `revert`, `am`, and `git push` when they would write to a protected branch, and blocks file edits in a repository while one is checked out. Pulling, switching branches, and editing gitignored files stay allowed, as does the first commit of a new repository. If commits already landed on local `main`, create the feature branch from them and ask the user before resetting `main`. Only the user can lift the block, by starting Claude Code with `GIT_ALLOW_MAIN=1`.

## Creating a branch

Always branch from an up-to-date `main`:

```bash
git status                      # make sure the working tree is clean
git switch main
git pull --ff-only origin main  # update main from the remote
git switch -c <branch-name>
```

- If the working tree has uncommitted changes, stop and ask the user whether to commit, stash, or carry them onto the new branch. Don't discard them.
- If `git pull --ff-only` fails, local `main` has diverged from the remote. Report this to the user rather than merging or resetting.
- If the repository's default branch isn't `main` (check `git symbolic-ref refs/remotes/origin/HEAD`), use that branch instead and mention it.

## Updating a branch from main

Branches should be short-lived. To pick up new changes from `main`, rebase:

```bash
git fetch origin
git rebase origin/main
```

- If the branch is already pushed and others may have pulled it, ask before rebasing; otherwise merge `origin/main` instead.
- After rebasing a pushed branch, push with `git push --force-with-lease`, never plain `--force`.
- Resolve conflicts carefully. If a conflict is ambiguous, show it to the user instead of guessing.
