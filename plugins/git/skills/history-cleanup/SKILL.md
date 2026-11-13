---
name: history-cleanup
description: Use when the user wants to tidy git history before merging - squashing, fixing up, rewording, reordering or dropping commits - or to undo a mistake and recover lost commits with the reflog.
---

# History cleanup

Rewriting history is fine on a private branch and risky on a shared one. Follow these rules first:

- **Never rewrite `main`** or any branch others build on.
- If the branch has been pushed, confirm with the user before rewriting, and push afterwards with `git push --force-with-lease`.
- Before any non-trivial rewrite, make a backup: `git branch backup/<branch-name>`. Delete it once the user is happy.
- Start from a clean working tree.

## Fixing up an earlier commit

Prefer fixup commits plus autosquash over editing commits by hand:

```bash
git commit --fixup=<sha>        # stage the fix first
git rebase -i --autosquash origin/main
```

Interactive editors may not be available to you. Run the rebase non-interactively by accepting the generated todo list as-is:

```bash
GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash origin/main
```

Use `--fixup=reword:<sha>` to change only an earlier commit's message.

## Squashing a whole branch into one commit

```bash
git reset --soft $(git merge-base HEAD origin/main)
git commit                      # write a fresh Conventional Commits message
```

## Amending the last commit

```bash
git commit --amend              # change message and/or add staged changes
git commit --amend --no-edit    # add staged changes, keep the message
```

## Undoing and recovery

- Undo the last commit, keep its changes staged: `git reset --soft HEAD~1`
- Undo a commit that is already on a shared branch: `git revert <sha>` (don't rewrite)
- Abort a rebase in progress: `git rebase --abort`
- Find "lost" commits after a bad reset or rebase:

  ```bash
  git reflog                       # find the sha from before the mistake
  git branch recovered/<name> <sha>
  ```

Avoid `git reset --hard` and `git clean -fd` unless the user asks for them explicitly; they discard work that the reflog can't always bring back (e.g. uncommitted changes).

## After cleanup

Show the result with `git log --oneline origin/main..HEAD` so the user can check it before anything is pushed.
