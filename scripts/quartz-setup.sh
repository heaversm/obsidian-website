#!/usr/bin/env bash
# Quartz v4 setup for GitHub Pages (deploy from MAIN via GitHub Actions).
# One-time setup + generates a one-step deploy script.
set -euo pipefail

fail(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' not found. Install it."; }

need node; need npm; need git; need rsync

echo "=== Quartz v4 — GitHub Pages Setup ==="
read -rp "Repo URL (e.g., git@github.com:you/repo.git): " ORIGIN_URL
[ -n "$ORIGIN_URL" ] || fail "Repo URL required."

read -rp "Full path to your Obsidian vault's PUBLIC folder: " VAULT_PUBLIC
[ -d "$VAULT_PUBLIC" ] || fail "Public folder not found."

read -rp "Parent folder for Quartz (e.g., $HOME/Sites): " QUARTZ_PARENT
[ -n "$QUARTZ_PARENT" ] || fail "Quartz parent folder required."

QUARTZ_DIR="${QUARTZ_PARENT%/}/quartz"
mkdir -p "$QUARTZ_PARENT"
rm -rf "$QUARTZ_DIR"
git clone https://github.com/jackyzha0/quartz.git "$QUARTZ_DIR"
cd "$QUARTZ_DIR"
npm i

echo "Answer prompts: Empty folder, File name → then press Enter"
read -r _
npx quartz create

# --- replace content with real folder ---
rm -rf content
mkdir -p content
rsync -a "$VAULT_PUBLIC"/ content/

# ensure homepage
if [ ! -f content/index.md ]; then
  cat > content/index.md <<'MD'
---
title: Home
---
# Welcome

This is your Quartz site. Put notes in **Public/** to publish them.
MD
fi

# --- init git ---
rm -rf .git
git init
git add .
git commit -m "Initial Quartz site"
git branch -M main
git remote add origin "$ORIGIN_URL" || git remote set-url origin "$ORIGIN_URL"

# --- derive baseUrl ---
if echo "$ORIGIN_URL" | grep -qE '^git@github\.com:'; then
  OWNER_REPO="$(echo "$ORIGIN_URL" | sed -E 's|^git@github\.com:([^/]+/[^.]+)(\.git)?$|\1|')"
else
  OWNER_REPO="$(basename "$(dirname "$ORIGIN_URL")")/$(basename "$ORIGIN_URL" .git)"
fi
OWNER="${OWNER_REPO%/*}"; REPO="${OWNER_REPO#*/}"
if echo "$REPO" | grep -qi '\.github\.io$'; then
  BASEURL="${OWNER}.github.io"
else
  BASEURL="${OWNER}.github.io/${REPO}"
fi
sed -i '' "s|baseUrl: .*|baseUrl: \"${BASEURL}\",|" quartz.config.ts
git add quartz.config.ts
git commit -m "Set baseUrl to ${BASEURL}" || true

# --- add GitHub Actions workflow ---
mkdir -p .github/workflows
cat > .github/workflows/deploy.yml <<'YAML'
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
      - run: npm ci
      - run: npx quartz build
      - uses: actions/upload-pages-artifact@v3
        with: { path: public }
  deploy:
    needs: build
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
YAML
git add .github/workflows/deploy.yml
git commit -m "Add deploy workflow" || true

# --- push main (with SSH keepalive) ---
GIT_SSH_COMMAND='ssh -o TCPKeepAlive=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=12 -o IPQoS=throughput' git push -u origin main

# --- generate deploy script ---
cat > deploy_main.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "\$(dirname "\$0")"
PUBLIC_DIR="$VAULT_PUBLIC"
rm -rf content
mkdir -p content
rsync -a --delete "\$PUBLIC_DIR"/ content/
if [ ! -f content/index.md ]; then
  cat > content/index.md <<'MD'
---
title: Home
---
# Welcome

This is your Quartz site. Put notes in **Public/** to publish them.
MD
fi
git add -A
git commit -m "Update notes: \$(date -u +'%Y-%m-%d %H:%M:%S UTC')" || true
git push origin main
EOF
chmod +x deploy_main.sh

# --- double-click app ---
cat > "Deploy Quartz.command" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./deploy_main.sh
read -n 1 -s -r -p "Done. Press any key to close..."
EOF
chmod +x "Deploy Quartz.command"

echo "=================================================================="
echo "✅ Setup complete."
echo "1) In GitHub → Settings → Pages → set Source = GitHub Actions"
echo "2) Publish any time with ./deploy_main.sh or double-click Deploy Quartz.command"
echo "Site URL: https://${OWNER}.github.io/${REPO}/"
echo "=================================================================="
