---
name: sync-upstream-my-work
description: Synchronize a fork that keeps `main` aligned with an official `upstream/main` branch and carries custom changes on a long-lived `my-work` branch. Use when Codex needs to fetch upstream changes, fast-forward local `main`, merge or rebase those updates into `my-work`, preserve GitHub Packages publishing from the custom branch, or recover the split between official code and fork-specific changes.
---

# Sync Upstream My Work

## Overview

Keep `main` as the upstream-tracking branch and keep custom package and publishing changes on `my-work`.
Use the bundled script for the default workflow so branch switching, fast-forward checks, and merge strategy stay consistent.

The primary goal is not to keep every historical package or local file forever.
The goal is to keep the fork close to official upstream while preserving the small set of intentional fork changes: package identities, GitHub Packages publishing, and explicitly requested source-level customizations.
When upstream removes old official modules that the fork did not intentionally customize, accept the upstream removal.

## Workflow

Assume this branch model unless the user says otherwise:

- `upstream/main`: official source branch
- `main`: local branch that should match `upstream/main`
- `my-work`: long-lived custom branch used for local changes and GitHub Packages publishing
- `origin`: the user's fork

Run this order:

1. Verify the worktree is clean before switching branches.
2. Fetch `upstream`.
3. Switch to `main`.
4. Fast-forward `main` to `upstream/main`.
5. Optionally push `main` to `origin/main`.
6. Switch to `my-work`.
7. Merge `main` into `my-work` by default.

Prefer `merge` for `my-work` because it is a published branch used for GitHub Packages and Actions. Use `rebase` only when the user explicitly wants rewritten history and the branch is safe to rewrite.

## Success Criteria

Do not treat the task as finished unless all of these are true:

1. Local `main` fast-forwards to `upstream/main`.
2. Official updates are merged or rebased into `my-work`.
3. Fork-specific GitHub Packages settings are still intact on `my-work`.
4. Verification confirms the custom package names did not revert to official scope.

## Non-Negotiable Invariants

Preserve these exact package identities on `my-work`:

- `packages/agent/package.json`: `@enjoywt/pi-agent-core`
- `packages/ai/package.json`: `@enjoywt/pi-ai`
- `packages/coding-agent/package.json`: `@enjoywt/pi-coding-agent`

Preserve these exact publishing constraints on `my-work`:

- `packages/agent/package.json`: `publishConfig.registry = https://npm.pkg.github.com`
- `packages/ai/package.json`: `publishConfig.registry = https://npm.pkg.github.com`
- `packages/coding-agent/package.json`: `publishConfig.registry = https://npm.pkg.github.com`
- `.github/workflows/publish-github-packages.yml` must still exist if the fork publishes through Actions

When upstream changes touch package metadata, keep upstream functional changes and version bumps, but do not let package names or GitHub Packages registry settings fall back to `@mariozechner/*` or npmjs.org for these three packages.

## Command

Use the bundled script:

```bash
.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh
```

Useful variants:

```bash
.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh --dry-run
.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh --push-main
.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh --strategy rebase
.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh --verify-only
```

## Conflict Handling

If merging `main` into `my-work` conflicts:

1. Resolve only the conflicted files.
2. For the three publishable fork packages, prefer this merge policy:
   Keep upstream code and version updates.
   Keep fork package names, fork repository URLs, and GitHub Packages registry settings.
3. If internal dependency versions are updated by upstream, keep the newer version number but point fork packages back to the matching `@enjoywt/*` names.
4. Rebuild lockfiles or regenerate derived files when package identity changes require it.
5. Run verification before concluding the merge.
6. Stage the resolved files with explicit `git add <path>` commands.
7. Continue the in-progress operation:
   For merge: `git commit`
   For rebase: `git rebase --continue`

For delete/modify conflicts, distinguish old upstream code from fork intent.
If the fork only changed package metadata for a module that upstream deleted, accept upstream deletion.
Do not keep removed modules merely because prior fork package-name rewrites touched their `package.json` files.

Do not use destructive reset or checkout commands to escape conflicts unless the user explicitly asks for that.

## Keep vs Delete Rules

When resolving conflicts, decide from evidence instead of asking the user repeatedly.

Keep fork-side changes when they are one of:

- The three package identities and GitHub Packages registry settings listed above.
- `.github/workflows/publish-github-packages.yml` or other fork publishing infrastructure.
- Source-level behavior that appears in fork-only commits, such as queue behavior or prompt metadata.
- Documentation or scripts under `.codex/skills/sync-upstream-my-work/`.

Accept upstream changes or deletions when:

- Upstream deleted a module and the fork only changed package metadata, lockfile entries, versions, or package names for that module.
- The change is a broad official refactor, dependency migration, file removal, or generated-file update unrelated to the fork's explicit publishing/custom behavior.
- Keeping the file would reintroduce an upstream-removed package such as a stale workspace.

Use these commands to classify intent:

```bash
git log --oneline main..HEAD -- <path>
git diff --stat main..HEAD -- <path>
git show --stat --oneline <fork-commit>
```

Ask the user only when the conflict touches nontrivial fork-only source behavior and the correct outcome is ambiguous.
Do not ask for old-module delete/modify conflicts where the only fork-side change is package metadata; accept upstream deletion.

## Publishing Notes

Published GitHub Packages depend on the contents and version numbers on `my-work`, not on `main`.
Keep package scope and GitHub Packages workflow changes on `my-work`, then sync official updates from `main` into it.
If upstream introduces package metadata conflicts, treat preservation of the three `@enjoywt/*` package identities as a release-blocking requirement.

For the GitHub Packages publish workflow, install dependencies from the normal npm registry/CDN first, then configure GitHub Packages auth only before `npm publish`.
Do not set `actions/setup-node` `registry-url: https://npm.pkg.github.com` before `npm ci`; that can make public dependencies resolve against GitHub Packages.
Use `npm ci` for CI installs and keep the repo on npm unless the user explicitly asks to migrate package managers.

If publishing fails with `npm error code ETARGET` for `xlsx@0.20.3`, do not change it to a registry version.
In this repo `xlsx` 0.20.3 is intentionally installed from the SheetJS CDN tarball:
`https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz`.
Preserve that package.json dependency and ensure `package-lock.json` includes `resolved` and `integrity` for `node_modules/xlsx`.

If GitHub Actions warns that Node.js 20 actions are deprecated, prefer updating official actions to Node 24-compatible major versions, such as `actions/checkout@v5` and `actions/setup-node@v5`, before changing the project Node runtime.

## Resources

### scripts/sync-fork.sh
Synchronize `main` with `upstream/main`, optionally push `origin/main`, merge or rebase `main` into `my-work`, then verify that fork package identities and GitHub Packages registry settings are still correct.
