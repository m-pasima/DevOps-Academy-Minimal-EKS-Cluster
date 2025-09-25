Param()

Write-Host "Scanning tracked files for sensitive patterns (tfvars/tfstate/.env/keys)..."
$matches = git ls-files | Select-String -Pattern '\.tfvars$|\.tfstate($|\.)|(^|/)\.env($|\.)|\.pem$|\.key$'

if (-not $matches) {
  Write-Host "No tracked sensitive files detected."
  exit 0
}

Write-Host "These tracked files look sensitive:" -ForegroundColor Yellow
$matches | ForEach-Object { $_.ToString() }
Write-Host
Write-Host "To stop tracking them while keeping local copies, run:" 
Write-Host "  git rm --cached <file...>"
Write-Host "Example:" 
$matches | ForEach-Object { $_.ToString() } | ForEach-Object { Write-Host "git rm --cached `"$_`"" }
Write-Host
Write-Host "Then commit and push. If secrets already exist in history, consider rewriting history with BFG or git-filter-repo."
Write-Host "Reminder: ensure .gitignore covers these patterns."

