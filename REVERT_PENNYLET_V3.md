# Revert PennyLet V3

V3 checkpoint created: 2026-06-01 19:45:15 Asia/Shanghai

## Backup Location

`.codex-backups/pre-pennylet-v3-20260601-194515/`

It contains:

- `git-status.txt`
- `git-head.txt`
- `git-diff.patch`
- `git-diff-staged.patch`
- `project-summary.md`
- `revert-instructions.md`
- `source-tree-v2-current.tar.gz`

## Branches

- V2 backup branch: `codex/backup-v2-before-v3-20260601-194515`
- V3 working branch: `codex/pennylet-v3-differentiation-20260601-194515`

## Revert With Git

```sh
git switch codex/backup-v2-before-v3-20260601-194515
git apply .codex-backups/pre-pennylet-v3-20260601-194515/git-diff.patch
git apply --index .codex-backups/pre-pennylet-v3-20260601-194515/git-diff-staged.patch
```

## Revert With Archive

```sh
mkdir -p /tmp/pennylet-v2-restore
tar -xzf .codex-backups/pre-pennylet-v3-20260601-194515/source-tree-v2-current.tar.gz -C /tmp/pennylet-v2-restore
```

Then copy the restored files back into this repo if needed.

## What V3 Is Allowed To Change

V3 can change product positioning, onboarding, help, AI prompts, upgrade copy, and supporting docs. It should preserve the V2 local-first money logic unless a bug fix is necessary.
