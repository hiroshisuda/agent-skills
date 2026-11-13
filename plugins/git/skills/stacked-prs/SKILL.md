---
name: stacked-prs
description: Use when the user wants to split work into stacked (dependent) pull requests - creating a stack, adding a layer, fixing a lower layer after review, syncing or restacking, viewing or merging a stack. Uses the gh stack extension (github/gh-stack).
---

# Stacked PRs with gh stack

A stack is a chain of branches where each one builds on the one below it. Each PR targets the branch beneath it, and GitHub links the PRs into a stack:

```
main ← auth-model ← auth-api ← auth-ui
       PR 1         PR 2       PR 3
```

Use the [`gh stack`](https://github.com/github/gh-stack) extension for all stack operations. Don't hand-roll stacks with `git rebase` and `gh pr create --base`. Follow the `branching` and `commit-messages` skills for names and messages.

## Prerequisites

Check once per session before using it:

```bash
gh auth status
gh stack --help >/dev/null 2>&1 || echo "gh stack not installed"
```

- Not authenticated: ask the user to run `gh auth login`. Don't log in for them.
- Extension missing: ask before installing, then run `gh extension install github/gh-stack`.
- It needs Git 2.36 or later.
- With more than one remote, pass `--remote <name>` to `push`, `submit`, `sync`, `rebase` and `link`, unless `remote.pushDefault` is set.

## Running it as an agent

Many `gh stack` commands open prompts, menus or a full-screen editor. Always use the non-interactive forms:

| Do | Don't |
|----|-------|
| `gh stack init <branch>` | bare `init` (prompts) |
| `gh stack add <branch>` | bare `add`, or `add -m` without a name (auto-generates a date-slug name that breaks the naming convention) |
| `gh stack submit --auto` | bare `submit` (opens an editor) |
| `gh stack view --json` | bare `view` (paged output) |
| `gh stack checkout <pr-or-branch>` | bare `checkout` (menu) |
| `gh stack up` / `down` / `top` / `bottom` | `gh stack switch` (menu only) |
| `gh stack merge <pr> --yes` | `gh pr merge` (can't merge a stack) |
| | `gh stack modify` (TUI only) |

Read state from `gh stack view --json` on stdout, and act on exit codes rather than stderr text:

| Exit code | Meaning |
|-----------|---------|
| 2 | Not in a stack, or not found |
| 3 | Rebase conflict |
| 4 | GitHub API failure |
| 6 | Ambiguous target; be more specific |
| 7 | A rebase is already in progress; continue or abort it first |
| 8 | Stack locked by another process; wait and retry |

## Plan the stack first

Before writing code, agree with the user on the layers. Each layer should be one reviewable, independently mergeable concern, ordered so lower layers never depend on higher ones. Three or four layers is usually plenty. Name each branch for the change it implements (see `branching`).

## Create the stack

Start from an up-to-date `main` (as in the `branching` skill), then:

```bash
gh stack init auth-model          # first layer, on top of trunk
# ...edit, then commit in Conventional Commits form...
gh stack add auth-api             # next layer, on top of the current top
# ...edit, commit...
gh stack add auth-ui
# ...edit, commit...
```

`gh stack add` only works from the top branch. Run `gh stack top` first if needed.

## Open the PRs

```bash
gh stack submit --auto --open
gh stack view --json
```

- `submit` pushes every branch, creates one PR per branch with the right bases, and links them as a GitHub stack.
- `--auto` gives PRs generated titles. Afterwards, set each title in Conventional Commits form (it often becomes the squash-merge commit), and write a short body saying why the change was made:

  ```bash
  gh pr edit <number> --title "feat(auth): add user model" --body-file <file>
  ```

- Drop `--open` to create the PRs as drafts, for example if the user wants reviewers to start at the bottom.

## Change a lower layer after review

Commit on the layer that owns the change, never on the top branch:

```bash
gh stack checkout auth-model     # or: gh stack down
# ...commit the fix...
gh stack rebase --upstack        # replay everything above it
gh stack top
gh stack push                    # atomic push with --force-with-lease
```

## Keep the stack current

```bash
gh stack sync --prune
```

`sync` fetches, fast-forwards trunk, rebases the stack if trunk moved (including over squash-merged layers), pushes, and deletes local branches whose PRs merged. It never opens PRs; use `submit` for new layers.

- If the local and remote stacks have diverged, `sync` aborts without pushing when it isn't run in a terminal. Show the user `gh stack view --json` and ask how to proceed.
- If `sync` hits a conflict, it restores the branches. Run `gh stack rebase` to bring the conflict back, then resolve it as below.

## Resolve conflicts (exit code 3)

1. Resolve the conflicted files and `git add` them.
2. Run `gh stack rebase --continue`.
3. If the right resolution isn't clear, run `gh stack rebase --abort` and show the user the conflict.

## Merge

Merge only when the user asks. Merges go bottom-up and are all-or-nothing up to the chosen PR:

```bash
gh stack merge <pr-number> --yes
```

Without a method flag, `merge` reuses the last method used. If the user hasn't said which to use, ask, then pass `--squash`, `--merge` or `--rebase`. Repos with a merge queue ignore the flag. Branch protection still applies and can't be bypassed. Afterwards, run `gh stack sync --prune`.

## Reorder or remove layers

`gh stack modify` is interactive only. Ask the user to run it themselves, or `gh stack unstack` and `gh stack init` again with the new order. Removing a layer is hard to undo, so confirm with the user first.

## Safety

- Use `gh stack push` or `submit` to push stack branches; both use `--force-with-lease`. Never plain `git push --force`.
- If someone else has pushed to a branch in the stack, ask before rewriting it.
- Don't commit a lower layer's concern on a higher branch to save time. It defeats the point of the stack.
