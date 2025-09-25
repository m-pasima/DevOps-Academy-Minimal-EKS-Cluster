#!/usr/bin/env bash
set -euo pipefail

echo "Scanning tracked files for sensitive patterns (tfvars/tfstate/.env/keys)..."
MATCHES=$(git ls-files | grep -E '\.tfvars$|\.tfstate($|\.)|(^|/)\.env($|\.)|\.pem$|\.key$' || true)

if [[ -z "$MATCHES" ]]; then
  echo "No tracked sensitive files detected."
  exit 0
fi

echo "These tracked files look sensitive:"
echo "$MATCHES"
echo
echo "To stop tracking them while keeping local copies, run:" 
echo "  git rm --cached <file...>"
echo "Example:" 
echo "$MATCHES" | xargs -r -n 50 echo git rm --cached
echo
echo "Then commit and push. If secrets already exist in history, consider rewriting history with BFG or git-filter-repo."
echo "BFG quickstart:"
echo "  bfg --replace-text replacements.txt --no-blob-protection .git"
echo
echo "Reminder: ensure .gitignore covers these patterns."

