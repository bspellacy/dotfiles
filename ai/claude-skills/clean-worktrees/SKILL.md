---
name: clean-worktrees
description: Remove git worktrees whose branches have been merged into the current branch
allowed-tools: Bash
---

Clean up git worktrees whose branches have already been merged into the current branch.

## Steps

1. Run `git worktree list --porcelain` to get all worktrees and their branches.
2. Run `git branch --merged` to get branches merged into the current branch.
3. Identify worktrees (excluding the main worktree) whose branch appears in the merged list.
4. For each matched worktree:
   - Run `git worktree remove <path>` to remove it.
   - Run `git branch -d <branch>` to delete the merged branch.
5. Report what was cleaned up, or confirm there was nothing to clean.

## Rules

- Never remove the main worktree (the first one listed by `git worktree list`).
- Never delete the current branch or the default branch (main/master).
- Use `git branch -d` (not `-D`) so only fully-merged branches are deleted.
- If a worktree has uncommitted changes, warn the user and skip it.
- Show a summary of what will be removed and ask for confirmation before proceeding.
