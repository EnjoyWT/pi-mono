#!/usr/bin/env bash
set -euo pipefail

repo_path="$(pwd)"
main_branch="main"
work_branch="my-work"
upstream_remote="upstream"
origin_remote="origin"
strategy="merge"
push_main="false"
dry_run="false"
verify_only="false"

usage() {
	echo "Usage: sync-fork.sh [options]"
	echo
	echo "Options:"
	echo "  --repo PATH              Repository path. Default: current directory"
	echo "  --main-branch NAME       Main branch name. Default: main"
	echo "  --work-branch NAME       Custom branch name. Default: my-work"
	echo "  --upstream-remote NAME   Upstream remote name. Default: upstream"
	echo "  --origin-remote NAME     Origin remote name. Default: origin"
	echo "  --strategy merge|rebase  How to update the work branch. Default: merge"
	echo "  --push-main              Push updated main to origin after sync"
	echo "  --verify-only            Only verify fork package invariants on the work branch"
	echo "  --dry-run                Print commands without mutating the repo"
	echo "  --help                   Show this help"
}

run_cmd() {
	printf '+'
	for arg in "$@"; do
		printf ' %q' "$arg"
	done
	printf '\n'
	if [[ "$dry_run" == "false" ]]; then
		"$@"
	fi
}

ensure_clean_tree() {
	if [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
		echo "Worktree is not clean. Commit or stash your changes before syncing." >&2
		exit 1
	fi
}

ensure_remote() {
	local remote_name="$1"
	if ! git -C "$repo_path" remote get-url "$remote_name" >/dev/null 2>&1; then
		echo "Remote '$remote_name' does not exist in $repo_path." >&2
		exit 1
	fi
}

ensure_branch() {
	local branch_name="$1"
	if ! git -C "$repo_path" show-ref --verify --quiet "refs/heads/$branch_name"; then
		echo "Local branch '$branch_name' does not exist in $repo_path." >&2
		exit 1
	fi
}

current_branch() {
	git -C "$repo_path" branch --show-current
}

verify_fork_config() {
	REPO_PATH="$repo_path" node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const repo = process.env.REPO_PATH;
const required = [
	{
		file: "packages/agent/package.json",
		name: "@enjoywt/pi-agent-core",
		registry: "https://npm.pkg.github.com",
	},
	{
		file: "packages/ai/package.json",
		name: "@enjoywt/pi-ai",
		registry: "https://npm.pkg.github.com",
	},
	{
		file: "packages/coding-agent/package.json",
		name: "@enjoywt/pi-coding-agent",
		registry: "https://npm.pkg.github.com",
	},
];

for (const item of required) {
	const filePath = path.join(repo, item.file);
	const parsed = JSON.parse(fs.readFileSync(filePath, "utf8"));
	if (parsed.name !== item.name) {
		console.error(`${item.file}: expected name ${item.name}, got ${parsed.name}`);
		process.exit(1);
	}
	if (parsed.publishConfig?.registry !== item.registry) {
		console.error(
			`${item.file}: expected publishConfig.registry ${item.registry}, got ${parsed.publishConfig?.registry}`,
		);
		process.exit(1);
	}
}

const workflow = path.join(repo, ".github/workflows/publish-github-packages.yml");
if (!fs.existsSync(workflow)) {
	console.error("Missing .github/workflows/publish-github-packages.yml");
	process.exit(1);
}

console.log("Fork package verification passed.");
NODE
}

verify_lockfile_platform_deps() {
	local checker="$repo_path/scripts/check-lockfile-platform-deps.mjs"
	if [[ ! -f "$checker" ]]; then
		echo "Missing scripts/check-lockfile-platform-deps.mjs" >&2
		exit 1
	fi
	run_cmd node "$checker" "$repo_path"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--repo)
			repo_path="$2"
			shift 2
			;;
		--main-branch)
			main_branch="$2"
			shift 2
			;;
		--work-branch)
			work_branch="$2"
			shift 2
			;;
		--upstream-remote)
			upstream_remote="$2"
			shift 2
			;;
		--origin-remote)
			origin_remote="$2"
			shift 2
			;;
		--strategy)
			strategy="$2"
			shift 2
			;;
		--push-main)
			push_main="true"
			shift
			;;
		--verify-only)
			verify_only="true"
			shift
			;;
		--dry-run)
			dry_run="true"
			shift
			;;
		--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
	esac
done

if [[ "$strategy" != "merge" && "$strategy" != "rebase" ]]; then
	echo "Invalid strategy '$strategy'. Use 'merge' or 'rebase'." >&2
	exit 1
fi

if [[ ! -d "$repo_path/.git" ]]; then
	echo "Repository path '$repo_path' is not a Git repository." >&2
	exit 1
fi

ensure_remote "$upstream_remote"
ensure_remote "$origin_remote"
ensure_branch "$main_branch"
ensure_branch "$work_branch"

if [[ "$verify_only" == "true" ]]; then
	if [[ "$(current_branch)" != "$work_branch" ]]; then
		echo "verify-only must be run with '$work_branch' checked out." >&2
		exit 1
	fi
	if [[ "$dry_run" == "false" ]]; then
		verify_fork_config
		verify_lockfile_platform_deps
	fi
	exit 0
fi

ensure_clean_tree

run_cmd git -C "$repo_path" fetch "$upstream_remote"
run_cmd git -C "$repo_path" switch "$main_branch"
run_cmd git -C "$repo_path" merge --ff-only "$upstream_remote/$main_branch"

if [[ "$push_main" == "true" ]]; then
	run_cmd git -C "$repo_path" push "$origin_remote" "$main_branch"
fi

run_cmd git -C "$repo_path" switch "$work_branch"

if [[ "$strategy" == "merge" ]]; then
	run_cmd git -C "$repo_path" merge "$main_branch"
else
	run_cmd git -C "$repo_path" rebase "$main_branch"
fi

if [[ "$dry_run" == "false" ]]; then
	verify_fork_config
	verify_lockfile_platform_deps
fi

echo
echo "Sync complete."
echo "  main branch: $main_branch"
echo "  work branch: $work_branch"
echo "  strategy: $strategy"
