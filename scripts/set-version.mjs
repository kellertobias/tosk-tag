#!/usr/bin/env node
// Write one semantic version into every authoritative version surface.
// Today that is the repo-root VERSION file, which ./build reads to stamp the app bundle
// (CFBundleShortVersionString). Safe to run by hand; used by the Forgejo release job.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const version = process.argv[2];
if (!/^\d+\.\d+\.\d+$/.test(version ?? "")) {
  console.error("usage: node scripts/set-version.mjs <major.minor.patch>");
  process.exit(2);
}

const versionFile = resolve(ROOT, "VERSION");
const current = readFileSync(versionFile, "utf8").trim();
writeFileSync(versionFile, `${version}\n`);
console.log(`VERSION: ${current} -> ${version}`);
