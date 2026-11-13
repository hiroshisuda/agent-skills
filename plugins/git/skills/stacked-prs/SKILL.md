---
name: stacked-prs
description: Use when the user wants to split work into stacked (dependent) pull requests with the gh CLI - creating a stack, adding a PR on top, updating PRs after review changes lower in the stack, or restacking after the bottom PR merges.
---

# Stacked PRs with gh

A stack is a chain of branches where each one builds on the one below it, and each PR targets the branch beneath it instead of `main`:

```
main ← auth-model ← auth-api ← auth-ui
       PR 1         PR 2       PR 3
```

Reviewers see one small diff per PR. Follow the `branching` and `commit-messages` skills for names and messages.

## Prerequisites

- `gh` is installed and authenticated: `gh auth status`. If not, tell the user to run `gh auth login`; don't try to log in for them.
- Git 2.38 or later for `--update-refs` (`git --version`). Without it, restack each branch by hand (see below).

## Plan the stack first

Before writing code, agree with the user on the layers. Each layer should be one reviewable, independently mergeable change, ordered so lower layers don't depend on higher ones. Three or four layers is usually plenty.

## Create the stack

Start from an up-to-date `main` (as in the `branching` skill), then for each layer:

```bash
git switch -c auth-model             # first branch: off main
# ...commit...
git push -u origin auth-model
gh pr create --base main --head auth-model --title "feat(auth): add user model" --body "..."

git switch -c auth-api               # next branch: off the one below
# ...commit...
git push -u origin auth-api
gh pr create --base auth-model --head auth-api --title "feat(auth): add login endpoint" --body "..."
```

The key is `--base <branch below>`. Without it, the PR targets `main` and shows every lower layer's diff too.

- Title each PR in Conventional Commits form, since it often becomes the squash-merge commit.
- Open upper PRs as drafts (`--draft`) if the user wants reviewers to start at the bottom.
- In each PR body, add a short stack section so reviewers can navigate. Update it on every PR when the stack changes:

  ```markdown
  **Stack** (review bottom-up)
  1. #101 feat(auth): add user model
  2. #102 feat(auth): add login endpoint  ← this PR
  3. #103 feat(auth): add login form
  ```

  Use `gh pr edit <number> --body-file <file>` to update it.

## Change a lower PR after review

Commit the fix on the lower branch, then rebase everything above it. Check out the **top** branch and let git move all intermediate branches at once:

```bash
git switch auth-model
# ...commit review fixes...
git switch auth-ui                    # top of the stack
git rebase --update-refs auth-model
git push --force-with-lease origin auth-api auth-ui
git push origin auth-model
```

Without `--update-refs`, rebase each branch onto the one below it, bottom to top:

```bash
git switch auth-api && git rebase auth-model
git switch auth-ui  && git rebase auth-api
```

## After the bottom PR merges

1. Check what happened: `gh pr view <number> --json state,mergeCommit`.
2. Retarget the next PR. GitHub does this automatically when the merged branch is deleted; otherwise:

   ```bash
   gh pr edit <next-number> --base main
   ```

3. Restack the remaining branches onto `main`. If the bottom PR was squash-merged, its commits aren't in `main` under the same hashes, so cut them out with `--onto`:

   ```bash
   git fetch origin
   git switch auth-ui
   git rebase --update-refs --onto origin/main auth-model
   git push --force-with-lease origin auth-api auth-ui
   ```

4. Delete the merged branch locally: `git branch -d auth-model` (use `-D` only after confirming it merged, since a squash merge makes `-d` refuse).
5. Update the stack section in the remaining PR bodies.

Merge strictly bottom-up. Never merge an upper PR first: it would land the lower layers' commits into the wrong branch.

## Check the state of a stack

```bash
gh pr list --author @me --json number,title,headRefName,baseRefName,state
git log --oneline --graph origin/main..auth-ui
```

## Safety

- Force-push only branches in this stack, and only with `--force-with-lease`.
- If someone else has pushed to a branch in the stack, ask before rewriting it.
- If a rebase hits a conflict you can't resolve confidently, stop with `git rebase --abort` and show the user.
