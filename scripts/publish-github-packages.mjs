#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const packages = [
	{ directory: "packages/ai", name: "@enjoywt/pi-ai" },
	{ directory: "packages/agent", name: "@enjoywt/pi-agent-core" },
	{ directory: "packages/coding-agent", name: "@enjoywt/pi-coding-agent" },
];

const registry = "https://npm.pkg.github.com";

function commandForPlatform(command) {
	return process.platform === "win32" ? `${command}.cmd` : command;
}

function run(command, args, options = {}) {
	console.log(`$ ${[command, ...args].join(" ")}`);
	const result = spawnSync(commandForPlatform(command), args, {
		cwd: options.cwd,
		encoding: "utf8",
		stdio: options.capture ? ["inherit", "pipe", "pipe"] : "inherit",
	});

	if (result.status !== 0) {
		const output = [result.stdout, result.stderr].filter(Boolean).join("\n");
		throw new Error(output ? `Command failed: ${command} ${args.join(" ")}\n${output}` : `Command failed: ${command} ${args.join(" ")}`);
	}

	return result;
}

function readPackageJson(directory) {
	return JSON.parse(readFileSync(join(directory, "package.json"), "utf8"));
}

function isPublished(name, version) {
	const result = spawnSync(commandForPlatform("npm"), ["view", `${name}@${version}`, "version", "--registry", registry, "--json"], {
		encoding: "utf8",
		stdio: ["inherit", "pipe", "pipe"],
	});

	if (result.status === 0 && result.stdout.trim()) {
		return true;
	}

	const output = [result.stdout, result.stderr].filter(Boolean).join("\n");
	if (result.status !== 0 && (output.includes("E404") || output.includes("404 Not Found"))) {
		return false;
	}

	throw new Error(output ? `Failed to query ${name}@${version}\n${output}` : `Failed to query ${name}@${version}`);
}

const packageVersions = new Map();
for (const pkg of packages) {
	const packageJson = readPackageJson(pkg.directory);
	if (packageJson.name !== pkg.name) {
		throw new Error(`${pkg.directory}/package.json has name ${packageJson.name}, expected ${pkg.name}`);
	}
	packageVersions.set(pkg.name, packageJson.version);
}

const versions = [...new Set(packageVersions.values())];
if (versions.length !== 1) {
	throw new Error(`GitHub Packages publish packages are not lockstep versioned: ${versions.join(", ")}`);
}

console.log(`Publishing GitHub Packages at ${versions[0]}\n`);

for (const pkg of packages) {
	const version = packageVersions.get(pkg.name);
	if (isPublished(pkg.name, version)) {
		console.log(`Skipping ${pkg.name}@${version}: already published\n`);
		continue;
	}

	run("npm", ["publish", "--workspace", pkg.directory, "--ignore-scripts"], { cwd: process.cwd() });
	console.log();
}
