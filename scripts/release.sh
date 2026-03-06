#!/bin/bash
set -e

# Read current version from package.json
CURRENT=$(grep '"version"' package.json | sed 's/.*"version": "\(.*\)".*/\1/')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

echo "Current version: $CURRENT"
echo ""
echo "Bump type:"
echo "  1) patch  ($MAJOR.$MINOR.$((PATCH + 1)))"
echo "  2) minor  ($MAJOR.$((MINOR + 1)).0)"
echo "  3) major  ($((MAJOR + 1)).0.0)"
echo ""
read -p "Select [1/2/3]: " CHOICE

case $CHOICE in
  1) NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))" ;;
  2) NEW_VERSION="$MAJOR.$((MINOR + 1)).0" ;;
  3) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
  *) echo "Invalid choice"; exit 1 ;;
esac

echo ""
echo "New version: $NEW_VERSION"
echo ""

# Collect release notes
echo "Enter release notes (empty line to finish):"
NOTES=""
while IFS= read -r LINE; do
  [ -z "$LINE" ] && break
  NOTES="$NOTES$LINE"$'\n'
done

if [ -z "$NOTES" ]; then
  NOTES="Release $NEW_VERSION"
fi

echo ""
echo "--- Summary ---"
echo "Version: $CURRENT -> $NEW_VERSION"
echo "Notes:"
echo "$NOTES"
echo "---------------"
echo ""
read -p "Proceed? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# Update package.json
sed -i '' "s/\"version\": \"$CURRENT\"/\"version\": \"$NEW_VERSION\"/" package.json
echo "Updated package.json to $NEW_VERSION"

# Commit, push, and create release
git add package.json
git commit -m "chore: bump version to $NEW_VERSION"
git push

gh release create "$NEW_VERSION" --title "$NEW_VERSION" --notes "$NOTES"
echo ""
echo "Release $NEW_VERSION created! Monitoring workflow..."
echo ""

# Wait for the release workflow to appear
sleep 5
RUN_ID=$(gh run list --workflow=release.yml --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -n "$RUN_ID" ]; then
  gh run watch "$RUN_ID"
  echo ""
  echo "Done! https://github.com/mehmetbaykar/swift-developer-docs-mcp/releases/tag/$NEW_VERSION"
else
  echo "Could not find workflow run. Check manually:"
  echo "  gh run list --limit 5"
fi
