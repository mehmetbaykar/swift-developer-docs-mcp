#!/usr/bin/env node

const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");

const BINARY_NAME = "swift-developer-docs-mcp";

function getPlatformKey() {
  const platform = os.platform();
  if (platform === "darwin") return "darwin-arm64";
  if (platform === "linux") return "linux-x64";
  return null;
}

function getBinaryPath() {
  const devPaths = [
    path.join(__dirname, ".build", "release", BINARY_NAME),
    path.join(__dirname, ".build", "debug", BINARY_NAME),
  ];
  for (const p of devPaths) {
    if (fs.existsSync(p)) return p;
  }

  const platformKey = getPlatformKey();
  if (platformKey) {
    const platformPath = path.join(__dirname, "bin", platformKey, BINARY_NAME);
    if (fs.existsSync(platformPath)) return platformPath;
  }

  const legacyPath = path.join(__dirname, "bin", BINARY_NAME);
  if (fs.existsSync(legacyPath)) return legacyPath;

  console.error(
    `Error: Binary not found for platform: ${os.platform()}-${os.arch()}`
  );
  console.error("");
  console.error("Supported platforms:");
  console.error("  - linux-x64 (Ubuntu 20.04+, Debian 11+)");
  console.error("  - darwin-arm64 (macOS 14+, Intel via Rosetta)");
  console.error("");
  console.error("Note: Windows and Alpine Linux are not supported.");
  process.exit(1);
}

const child = spawn(getBinaryPath(), process.argv.slice(2), {
  stdio: "inherit",
  env: process.env,
});

child.on("error", (err) => {
  if (err.message.includes("libcurl")) {
    console.error("Missing libcurl. Run: apt-get install libcurl4");
  } else {
    console.error(`Failed to start: ${err.message}`);
  }
  process.exit(1);
});

child.on("exit", (code, signal) => {
  if (signal) process.kill(process.pid, signal);
  else process.exit(code ?? 0);
});
