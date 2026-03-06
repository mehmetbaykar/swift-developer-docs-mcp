#!/bin/bash
set -euo pipefail

VERSION=${GITHUB_REF_NAME#v}

if [ -z "$VERSION" ]; then
  echo "Error: VERSION is empty. GITHUB_REF_NAME='${GITHUB_REF_NAME:-}'"
  exit 1
fi

mkdir -p bin/linux-x64 bin/darwin-arm64

cp artifacts/binary-Linux/swift-developer-docs-mcp bin/linux-x64/
cp artifacts/binary-macOS/swift-developer-docs-mcp bin/darwin-arm64/

chmod +x bin/*/swift-developer-docs-mcp

echo "Final binary sizes:"
ls -lh bin/*/swift-developer-docs-mcp

npm version "$VERSION" --no-git-tag-version --allow-same-version

echo "Package contents (dry run):"
npm pack --dry-run

npm publish --provenance --access public
