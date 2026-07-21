#!/usr/bin/env node
// Derive the next semantic version from Conventional Commits since the last v*.*.* tag.
// Prints the next version on stdout, or prints nothing (and exits 0) when no release is warranted.
//
// When no prior v* tag exists it prints nothing and asks for a baseline tag on stderr, so the
// project's accumulated history can never trigger a surprise release the first time CI runs.

import { execFileSync } from "node:child_process";

const git = (...args) => execFileSync("git", args, { encoding: "utf8" }).trim();

const tags = git("tag", "--list", "v*.*.*", "--sort=-v:refname")
  .split("\n")
  .filter(Boolean);
const lastTag = tags[0];

if (!lastTag) {
  process.stderr.write(
    "No v*.*.* tag found. Create a baseline tag once before enabling automatic releases:\n" +
      "  git tag v$(cat VERSION) && git push origin v$(cat VERSION)\n",
  );
  process.exit(0);
}

const range = `${lastTag}..HEAD`;
const log = git("log", range, "--no-merges", "--format=%B%x00");
const commits = log
  .split("\0")
  .map((entry) => entry.trim())
  .filter(Boolean);

const HEADER = /^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]*)\))?(?<breaking>!)?:\s+(?<subject>.+)$/;

let bump = 0; // 0 none, 1 patch, 2 minor, 3 major
for (const commit of commits) {
  const [header, ...body] = commit.split("\n");
  const match = HEADER.exec(header.trim());
  if (!match) continue;
  const { type, breaking } = match.groups;
  if (breaking || body.some((line) => /^BREAKING[ -]CHANGE:/.test(line.trim()))) {
    bump = Math.max(bump, 3);
  } else if (type === "feat") {
    bump = Math.max(bump, 2);
  } else if (type === "fix" || type === "perf" || type === "revert") {
    bump = Math.max(bump, 1);
  }
}

if (bump === 0) {
  process.exit(0);
}

const [major, minor, patch] = lastTag.slice(1).split(".").map(Number);
const next =
  bump === 3
    ? [major + 1, 0, 0]
    : bump === 2
      ? [major, minor + 1, 0]
      : [major, minor, patch + 1];

process.stdout.write(next.join("."));
