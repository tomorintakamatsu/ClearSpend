# Revert Local Money Logic V2

Checkpoint created before implementing Local Money Logic V2.

Backup folder:
`.codex-backups/pre-local-money-logic-v2-20260529-170028/`

Backup branch:
`backup/pre-local-money-logic-v2-20260529-170028`

Working feature branch:
`feature/local-first-money-logic-v2-20260529-170028`

## Revert With Git

1. Save any current work you want to keep.
2. Switch back to the backup branch:

```sh
git switch backup/pre-local-money-logic-v2-20260529-170028
```

3. If you also want the uncommitted work that existed at checkpoint time, apply:

```sh
git apply .codex-backups/pre-local-money-logic-v2-20260529-170028/git-diff.patch
```

Important: the backup branch points to the last committed base. The UI, wallpaper, AI, and other uncommitted app work that existed before Local Money Logic V2 is preserved in `git-diff.patch` and `source-tree.tar.gz`. To recreate the exact old-version app with the newer UI but the old money logic, switch to the backup branch and apply `git-diff.patch`.

## Revert With Patch Files

The checkpoint saved:

- `.codex-backups/pre-local-money-logic-v2-20260529-170028/git-diff.patch`
- `.codex-backups/pre-local-money-logic-v2-20260529-170028/git-diff-staged.patch`

To restore those changes onto a clean checkout:

```sh
git apply .codex-backups/pre-local-money-logic-v2-20260529-170028/git-diff.patch
git apply --cached .codex-backups/pre-local-money-logic-v2-20260529-170028/git-diff-staged.patch
```

## Revert With Source Archive

The checkpoint archive is:

`.codex-backups/pre-local-money-logic-v2-20260529-170028/source-tree.tar.gz`

Extract it into a separate folder, compare files, and copy back anything needed.
The archive excludes `.git`, generated builds, caches, and other heavy folders.

## In-App Legacy Toggle

The in-app legacy toggle has been removed. PennyLet now uses the local-first V2 money logic directly, with no Settings switch back to the old calculation path.

To return to the pre-V2 app, use the backup branch, patch files, or source archive above.

## Two App Versions

- Old version: backup checkpoint + `git-diff.patch` or `source-tree.tar.gz`. This is the app with your current UI, AI, wallpaper, and other changes, but without Local Money Logic V2.
- New version: `feature/local-first-money-logic-v2-20260529-170028`. This keeps the same UI, AI features, wallpaper implementation, subscriptions, goals, and existing flows, while using the new local-first V2 layer as the only app money logic.
