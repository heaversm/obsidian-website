# Obsidian Quartz Guide

### TLDR

* Make an empty public github repo
* Run the setup script
* Set up Github Pages to use Github Actions
* Copy the `quartz-deploy.sh` script into your quartz site root folder
* Make changes to your notes, then run the quartz-deploy.sh script



## Prereqs (once)
- macOS with **Node.js**, **npm**, **git**
- A **new empty GitHub repo** (no README/.gitignore). Example: `heaversm/dft-quartz`
- An Obsidian vault with a `Public/` folder (this is what you publish).

---

## Run the setup script
1) Download the script below.
2) In Terminal:
```bash
cd ~/Downloads
chmod +x ./quartz-setup-mac.sh
./quartz-setup-mac.sh
```
3) During Quartz’s one-time prompts, choose:
   - **Initialize content** → **Empty folder**
   - **Resolve links** → **File name**

What the script does:
- Clones Quartz, installs deps, scaffolds
- Symlinks `content → /path/to/YourVault/Public`
- Sets `baseUrl` based on your repo
  - If repo is `<owner>.github.io` → `baseUrl = "<owner>.github.io"`
  - Else → `baseUrl = "<owner>.github.io/<repo>"`
- Adds a GitHub **Actions** workflow that deploys on **push to `main`**
- Commits & pushes **main**

---

## Github UI
In your GithubRepo, go to: **Settings → Pages** → **Source = GitHub Actions**.

When you push to `main`, the Action builds & publishes your site to:
```
https://<owner>.github.io/<repo>/
```

e.g https://heaversm.github.ioi/dft-quartz/

---

## Everyday usage
From your Quartz folder:
```bash
./deploy.sh
```
This runs `npx quartz sync`, commits, and **pushes `main`** (which triggers the Action).

If you don’t want the helper script:
```bash
npx quartz sync
git add -A
git commit -m "Update notes" || true
git push origin main
```


