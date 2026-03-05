#!/bin/bash
set -e

VERSION=${GITHUB_REF_NAME#v}

mkdir -p bin/linux-x64 bin/darwin-arm64

cp artifacts/binary-Linux/swift-developer-docs-mcp bin/linux-x64/
cp artifacts/binary-macOS/swift-developer-docs-mcp bin/darwin-arm64/

chmod +x bin/*/swift-developer-docs-mcp

echo "Final binary sizes:"
ls -lh bin/*/swift-developer-docs-mcp

npm version "$VERSION" --no-git-tag-version --allow-same-version
npm publish --provenance --access public
