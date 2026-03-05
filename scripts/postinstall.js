#!/usr/bin/env node

const { execSync } = require("child_process");
const { existsSync } = require("fs");
const { join } = require("path");

const root = join(__dirname, "..");

// If already built, skip
if (existsSync(join(root, ".build", "release", "swift-developer-docs-mcp"))) {
  process.exit(0);
}

try {
  execSync("swift --version", { stdio: "ignore" });
} catch {
  console.error(
    "swift-developer-docs-mcp requires Swift 6.0+ on macOS 14+.\n" +
      "Install Xcode or Swift toolchain from https://swift.org/install"
  );
  process.exit(1);
}

console.log("Building swift-developer-docs-mcp...");
try {
  execSync("swift build -c release", { cwd: root, stdio: "inherit" });
  console.log("Build complete.");
} catch {
  console.error("Build failed. Run 'swift build' manually to see errors.");
  process.exit(1);
}
