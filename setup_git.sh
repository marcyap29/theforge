#!/bin/bash
# Run this once from The Forge directory to initialize git and push to GitHub
# Usage: bash setup_git.sh

cd "/Volumes/Marc Working Drive/Development/The Forge"

git init
git add -A
git commit -m "init: The Forge repo bootstrap from Starter Repo"
git branch -M main
git remote add origin https://github.com/marcyap29/theforge.git
git push -u origin main

echo "Done. The Forge is live at https://github.com/marcyap29/theforge"
