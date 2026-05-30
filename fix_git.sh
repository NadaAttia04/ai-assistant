#!/usr/bin/env bash
# fix_git.sh — Untrack Breast dataset.zip and sync with remote
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "==> Working in: $REPO_ROOT"

# Step 1: Ensure *.zip is in .gitignore (already present, but verify)
if grep -qF "*.zip" .gitignore; then
    echo "==> .gitignore already contains *.zip — nothing to add."
else
    echo "*.zip" >> .gitignore
    echo "==> Added *.zip to .gitignore."
fi

# Step 2: Untrack Breast dataset.zip without deleting the local file
ZIP_FILE="Breast dataset.zip"
if git ls-files --error-unmatch "$ZIP_FILE" 2>/dev/null; then
    git rm --cached "$ZIP_FILE"
    echo "==> Untracked '$ZIP_FILE' from Git index (local file kept)."
else
    echo "==> '$ZIP_FILE' is not tracked by Git — skipping git rm."
fi

# Step 3: Commit the .gitignore change (if anything changed in the index)
if ! git diff --cached --quiet; then
    git commit -m "chore: untrack Breast dataset.zip, ensure *.zip ignored"
    echo "==> Committed index cleanup."
else
    echo "==> No staged changes to commit."
fi

# Step 4: Pull latest from remote
echo "==> Pulling from remote..."
git pull

echo ""
echo "Done. Your repo is clean and up to date."
