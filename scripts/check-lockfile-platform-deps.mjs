import fs from "node:fs";
import path from "node:path";

const repoPath = process.argv[2] ?? process.cwd();
const lockPath = path.join(repoPath, "package-lock.json");
const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
const packages = lock.packages ?? {};

function dependencyPaths(parentPath, dependencyName) {
	const rootPath = `node_modules/${dependencyName}`;
	if (!parentPath) {
		return [rootPath];
	}
	const paths = [rootPath, `${parentPath}/node_modules/${dependencyName}`];
	const nestedNodeModules = "/node_modules/";
	const nodeModulesIndex = parentPath.lastIndexOf(nestedNodeModules);
	if (nodeModulesIndex !== -1) {
		paths.push(`${parentPath.slice(0, nodeModulesIndex)}${nestedNodeModules}${dependencyName}`);
	}
	return [...new Set(paths)];
}

const missing = [];

for (const [parentPath, entry] of Object.entries(packages)) {
	for (const [dependencyName, dependencyVersion] of Object.entries(entry.optionalDependencies ?? {})) {
		const hasLockEntry = dependencyPaths(parentPath, dependencyName).some((candidate) => packages[candidate]);
		if (!hasLockEntry) {
			missing.push({
				from: parentPath || ".",
				name: dependencyName,
				version: dependencyVersion,
			});
		}
	}
}

if (missing.length > 0) {
	console.error("package-lock.json is missing optional platform dependency entries.");
	console.error("GitHub Linux packaging uses npm ci, so native packages must be present in the lockfile.");
	console.error("");
	for (const item of missing) {
		console.error(`${item.from} -> ${item.name}@${item.version}`);
	}
	process.exit(1);
}

console.log("Lockfile platform dependency verification passed.");
