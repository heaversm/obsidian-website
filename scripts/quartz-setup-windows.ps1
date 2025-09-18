# Quartz v4 setup for GitHub Pages (deploy from MAIN via GitHub Actions) - Windows/PowerShell
# One-time setup + generates a one-step deploy script.

$ErrorActionPreference = 'Stop'

function Need($name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Required command '$name' not found. Install it and re-run."
  }
}

Need node
Need npm
Need git
Need npx
Need robocopy

Write-Host "=== Quartz v4 - GitHub Pages Setup (Windows) ===" -ForegroundColor Cyan

# --- Inputs ---
$originUrl     = Read-Host "Repo URL (e.g., git@github.com:you/repo.git or https://github.com/you/repo.git)"
if (-not $originUrl) { throw "Repo URL is required." }

$vaultPublic   = Read-Host "Full path to your Obsidian vault's PUBLIC folder (e.g., C:\Users\you\Obsidian\MyVault\Public)"
if (-not (Test-Path -Path $vaultPublic -PathType Container)) { throw "Public folder not found." }

$parentFolder  = Read-Host "Parent folder to create Quartz in (e.g., C:\Sites)"
if (-not $parentFolder) { throw "Parent folder is required." }

$quartzDir   = Join-Path $parentFolder "quartz"
$contentDir  = Join-Path $quartzDir "content"

# Remove any existing Quartz directory (parity with mac script)
if (Test-Path $quartzDir) {
  Write-Host "Removing existing directory: $quartzDir" -ForegroundColor Yellow
  Remove-Item -Recurse -Force $quartzDir
}
New-Item -ItemType Directory -Path $parentFolder -Force | Out-Null

# --- Clone & install Quartz ---
Write-Host "Cloning Quartz..." -ForegroundColor Yellow
git clone https://github.com/jackyzha0/quartz.git "$quartzDir" | Out-Null
Set-Location -Path "$quartzDir"

Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm i

Write-Host @"
------------------------------------------------------------
Quartz scaffolding (one-time):
1) "Choose how to initialize the content..." ->  Empty folder
2) "How should Quartz resolve links?"       ->  File name
(Press Enter to continue)
------------------------------------------------------------
"@
[void](Read-Host)
npx quartz create

# --- Replace content with REAL folder (no symlink) and copy Public -> content ---
if (Test-Path $contentDir) { Remove-Item -Recurse -Force $contentDir }
New-Item -ItemType Directory -Path $contentDir -Force | Out-Null

# Mirror (like rsync --delete) with robocopy
$rc = robocopy "$vaultPublic" "$contentDir" /MIR /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw "robocopy failed mirroring Public -> content" }

# Ensure homepage so first deploy is never RSS/404
$indexPath = Join-Path $contentDir "index.md"
if (-not (Test-Path $indexPath)) {
@"
---
title: Home
---
# Welcome

This is your Quartz site. Put notes in **Public/** to publish them.
"@ | Set-Content -NoNewline -Encoding UTF8 $indexPath
  Write-Host "Created starter content/index.md"
}

# --- Fresh git init -> first commit on main ---
if (Test-Path ".git") { Remove-Item -Recurse -Force ".git" }
git init | Out-Null
git add . | Out-Null
git commit -m "Initial Quartz site (deploy from main via Actions)" | Out-Null
git branch -M main
git remote add origin "$originUrl" 2>$null; if ($LASTEXITCODE -ne 0) { git remote set-url origin "$originUrl" }

# --- Derive baseUrl from origin (no protocol; include repo for project sites) ---
function Parse-OwnerRepo($url){
  if ($url -match '^git@github\.com:(.+?)/(.+?)(\.git)?$') { return "$($Matches[1])/$($Matches[2])" }
  if ($url -match '^https?://github\.com/([^/]+)/([^/]+)(\.git)?$') { return "$($Matches[1])/$($Matches[2])" }
  throw "Unrecognized GitHub URL format: $url"
}
$ownerRepo = Parse-OwnerRepo $originUrl
$owner,$repo = $ownerRepo.Split('/')
if ($repo -match '\.github\.io$') { $baseUrl = "$owner.github.io" } else { $baseUrl = "$owner.github.io/$repo" }

# Patch baseUrl in quartz.config.ts (match single or double quotes)
(Get-Content quartz.config.ts -Raw) -replace 'baseUrl:\s*["''].*?["'']\s*,?', ('baseUrl: "' + $baseUrl + '",') |
  Set-Content -Encoding UTF8 quartz.config.ts
git add quartz.config.ts | Out-Null
git commit -m "Set baseUrl to $baseUrl" | Out-Null

# --- GitHub Actions workflow (deploy from main) ---
$wfPath = ".github/workflows/deploy.yml"
New-Item -ItemType Directory -Path ".github/workflows" -Force | Out-Null
@'
name: Deploy Quartz site to GitHub Pages
on:
  push:
    branches: [ main ]
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: "pages"
  cancel-in-progress: false
jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - name: Install Dependencies
        run: npm ci
      - name: Build Quartz
        run: npx quartz build
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: public
  deploy:
    needs: build
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
'@ | Set-Content -Encoding UTF8 $wfPath

git add $wfPath | Out-Null
git commit -m "Add GitHub Pages deploy workflow (deploy from main)" | Out-Null

# --- First push (with SSH keep-alives). Retry once if needed.
$env:GIT_SSH_COMMAND = 'ssh -o TCPKeepAlive=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=12 -o IPQoS=throughput'
try {
  git push -u origin main
} catch {
  Write-Host "First push failed. Retrying once..." -ForegroundColor Yellow
  git push -u origin main
}

# --- Generate one-step deploy script (Public -> content mirror, ensure homepage, push main) ---
$deployPs1 = Join-Path $quartzDir "deploy_main.ps1"
@"
# One-step Quartz deploy (Windows) - mirrors Obsidian Public -> content, ensures homepage, pushes main
`$ErrorActionPreference = 'Stop'
Set-Location "`$(Split-Path -Parent `$MyInvocation.MyCommand.Definition)"

# EDIT if your Public path changes:
`$PublicDir = "$vaultPublic"
`$ContentDir = "content"

# Replace any leftover symlink with real folder (Windows rarely creates repo symlinks, but be safe)
if (Test-Path `$ContentDir) {
  if ((Get-Item `$ContentDir).Attributes.ToString().Contains("ReparsePoint")) {
    Remove-Item -Force `$ContentDir
    New-Item -ItemType Directory -Path `$ContentDir | Out-Null
  }
} else {
  New-Item -ItemType Directory -Path `$ContentDir | Out-Null
}

# Mirror Public -> content (delete removed files)
robocopy "`$PublicDir" "`$ContentDir" /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
if (`$LASTEXITCODE -ge 8) { throw "robocopy failed" }

# Ensure homepage
if (-not (Test-Path (Join-Path `$ContentDir 'index.md'))) {
@'
---
title: Home
---
# Welcome

This is your Quartz site. Put notes in **Public/** to publish them.
'@ | Set-Content -NoNewline -Encoding UTF8 (Join-Path `$ContentDir 'index.md')
}

git add -A | Out-Null
git commit -m "Update notes: `$(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') UTC" 2>`$null | Out-Null
git push origin main
Write-Host "Deployed. Check GitHub -> Actions for the Pages run."
"@ | Set-Content -Encoding UTF8 $deployPs1

# Double-click launcher
$deployCmd = Join-Path $quartzDir "Deploy-Quartz.cmd"
@"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0deploy_main.ps1"
pause
"@ | Set-Content -Encoding ASCII $deployCmd

Write-Host ""
Write-Host "====================================================================" -ForegroundColor Green
Write-Host "Setup complete."
Write-Host "ONE UI STEP (once): Repo -> Settings -> Pages -> Source = GitHub Actions"
Write-Host ""
Write-Host "Publish anytime:"
Write-Host "  PowerShell :  $deployPs1"
Write-Host "  Double-click: $deployCmd"
Write-Host ""
$siteUrl = if ($repo -match '\.github\.io$') { "https://$owner.github.io/" } else { "https://$owner.github.io/$repo/" }
Write-Host ("Site URL: {0}" -f $siteUrl)
Write-Host "====================================================================" -ForegroundColor Green
