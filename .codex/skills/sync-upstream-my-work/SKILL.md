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
5. Verification confirms published source imports use the fork package scope.

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

Published source under `packages/agent/src` and `packages/coding-agent/src` must import fork packages with `@enjoywt/*`, not `@earendil-works/*`.
Docs, examples, and tests may keep official package scopes when they intentionally document or exercise external user-facing package names.

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
7. Continue the in-progress operation (see **Completing the merge commit** below).

### Completing the merge commit

Upstream ships a Husky **pre-commit** hook (`.husky/pre-commit`) that runs on every commit, including merge commits after syncing `main` into `my-work`.

Typical failures and fixes:

| Symptom | Cause | Fix |
|--------|--------|-----|
| `node: command not found` (exit 127) | GUI Git clients (e.g. SourceTree) use a minimal `PATH` without Homebrew/`/usr/local/bin` | Commit from a terminal, or prepend `/opt/homebrew/bin:/usr/local/bin` to `PATH` in the GUI client settings |
| `package-lock.json is staged` / `PI_ALLOW_LOCKFILE_CHANGE=1` (exit 1) | `scripts/check-lockfile-commit.mjs` blocks lockfile commits until dependency changes are explicitly acknowledged | After reviewing lockfile diffs and running `npm run check:lockfile`, finish the merge with `PI_ALLOW_LOCKFILE_CHANGE=1 git commit` |
| `Checks failed` during pre-commit | `npm run check` (format, types, shrinkwrap, optional browser smoke) failed | Fix reported errors, re-stage, commit again (lockfile override still required if `package-lock.json` is staged) |

**When the env var is required:** Any commit that stages `package-lock.json` with changes to external registry packages (normal after merging upstream). It is **not** required when the only lockfile diffs are workspace package metadata under `packages/*` (the script allows those automatically).

**Recommended finish after conflict resolution:**

```bash
npm run check:lockfile
PI_ALLOW_LOCKFILE_CHANGE=1 git commit
```

Use `--no-edit` to keep the default merge message. The bundled `sync-fork.sh` sets `PI_ALLOW_LOCKFILE_CHANGE=1` for a **clean** `git merge` (no conflicts); you must set it yourself for the manual commit after resolving conflicts.

**Why this may be new:** Upstream added the lockfile commit guard and expanded pre-commit checks in the dependency-hardening work (around v0.75.x). Forks that had not merged that line yet did not run these hooks locally.

### Lockfile Merge Checklist

When `package-lock.json` conflicts or package metadata changes:

1. Do not keep a platform-pruned lockfile that only contains the current macOS native optional packages.
2. Preserve or restore lock entries for every package listed under `optionalDependencies`, including non-current platforms.
3. Run `npm run check:lockfile` before committing the merge.
4. Commit with `PI_ALLOW_LOCKFILE_CHANGE=1` when `package-lock.json` is staged (see **Completing the merge commit**).
5. If the check reports missing entries for `@biomejs/biome`, `@typescript/native-preview`, `esbuild`, `rollup`, `lightningcss`, Tailwind oxide, or workspace optional native packages, fix `package-lock.json`; do not remove the check or downgrade tooling.
6. Be aware that `npm install --package-lock-only` on macOS may leave the lockfile unchanged if it already considers the current platform satisfied. Verify from the check output, not from whether npm changed files.
7. For workspace-local optional dependencies, ensure the check script recognizes sibling workspace paths such as `packages/coding-agent/node_modules/<native-package>`.

### Source Import Scope Checklist

When merging upstream code into `my-work`:

1. Replace official package imports in published source with the fork scope:
   `@earendil-works/pi-ai` -> `@enjoywt/pi-ai`
   `@earendil-works/pi-agent-core` -> `@enjoywt/pi-agent-core`
2. Check at least `packages/agent/src` and `packages/coding-agent/src`; these paths participate in package builds and publishing.
3. Do not rely only on package.json names. TypeScript can still fail if source imports reference the official package scope that is not installed.
4. Run `.codex/skills/sync-upstream-my-work/scripts/sync-fork.sh --verify-only` before treating the sync as ready.

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

The publishing target is GitHub's Linux runner.
Before treating a sync or publishing change as ready, run `npm run check:lockfile` so the lockfile is verified for Linux native optional packages.
The bundled sync script also runs `scripts/check-lockfile-platform-deps.mjs` during verification.
The GitHub publish and CI workflows must keep this check after `npm ci` and before build steps.
Do not work around missing native packages by removing `tsgo` or downgrading TypeScript tooling.
Every package listed under any `optionalDependencies` entry must have a corresponding lock entry, especially Linux x64 packages for `@typescript/native-preview`, `@biomejs/biome`, `esbuild`, `rollup`, `lightningcss`, and Tailwind oxide.
Package-level build configs must also match the APIs used by published packages.
If a Node package source uses `fetch`, `Response`, or `ReadableStream` directly, make its `tsconfig.build.json` include the appropriate Web API types, such as `lib: ["ES2022", "DOM"]`, so GitHub package builds do not depend on root-check-only type resolution.

## Resources

### scripts/sync-fork.sh
Synchronize `main` with `upstream/main`, optionally push `origin/main`, merge or rebase `main` into `my-work`, then verify that fork package identities and GitHub Packages registry settings are still correct.
