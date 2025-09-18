# Quartz v4 + GitHub Pages (Windows Setup Guide)

This guide shows you how to set up and publish your [Obsidian](https://obsidian.md) notes as a Quartz v4 site on **GitHub Pages** — using **PowerShell** on Windows.

The setup script does everything for you:

- Deploys from **`main`** (no `v4`, no `quartz sync`)
- Copies your Obsidian `Public/` folder → `content/` (no symlinks)
- Ensures a homepage exists (`index.md`) so the site never renders as RSS-only
- Sets the correct `baseUrl` automatically from your repo
- Creates a **one-step deploy script** and a **double-click launcher**

---

## 1. Prerequisites

Install these tools first:

- [Git](https://git-scm.com/download/win)  
- [Node.js](https://nodejs.org/) (LTS is fine)  
- [Obsidian](https://obsidian.md/) (with a `Public/` folder in your vault)

Verify installs in PowerShell:

```powershell
git --version
node --version
npm --version
```

---

## 2. Create a GitHub repo

1. Go to [GitHub](https://github.com) and create a new **public** repo (e.g., `dft-quartz`).
2. Copy the repo URL (SSH or HTTPS).

---

## 3. Download the setup script

Use the setup script included in this repository at `scripts/quartz-setup-windows.ps1`. You do not need to download a separate file.

---

## 4. Run the setup script

Open **PowerShell** and run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\quartz-setup-windows.ps1
```

The script will prompt you for:

- **Repo URL** → your GitHub repo (e.g., `git@github.com:you/dft-quartz.git`)  
- **Vault Public folder** → the full path to your Obsidian `Public/` folder  
- **Parent folder** → where to install Quartz locally (e.g., `C:\Sites`)  

When Quartz asks:

- **Initialize content** → `Empty folder`  
- **Resolve links** → `File name`

---

## 5. Configure GitHub Pages (one-time)

In your repo:

1. Go to **Settings → Pages**.  
2. Under **Build and deployment → Source**, select **GitHub Actions**.

---

## 6. Publish your notes

After setup, you now have two easy ways to publish:

The deploy files are written into the Quartz project folder created by the setup (the parent folder you chose, plus `\quartz`). For example, if you chose `C:\Sites` as the parent folder, the deploy files will be:

- `C:\Sites\quartz\deploy_main.ps1`
- `C:\Sites\quartz\Deploy-Quartz.cmd`

### Option A: PowerShell
```powershell
C:\Sites\quartz\deploy_main.ps1
```

### Option B: Double-click
Run the shortcut:  
```
C:\Sites\quartz\Deploy-Quartz.cmd
```

Both options:

- Copy your `Public/` vault → `content/`
- Ensure `content/index.md` exists
- Commit and push `main`
- Trigger the GitHub Action to rebuild and publish your site

---

## 7. View your site

Once the GitHub Action finishes (green check in **Actions** tab), your site is live at:

```
https://<username>.github.io/<repo>/
```

Example:
```
https://heaversm.github.io/dft-quartz/
```

---

## 8. Next steps

- Add notes/images to your Obsidian `Public/` folder to publish them.  
- Edit `content/index.md` (or replace it with a note in `Public/`) to customize your homepage.  
- Use `deploy_main.ps1` or `Deploy-Quartz.cmd` whenever you want to republish.

---

✅ That’s it. You now have a **repeatable Windows setup** for Quartz → GitHub Pages.

---

## 9. Troubleshooting

- **PowerShell blocks scripts**

  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

- **“REMOTE HOST IDENTIFICATION HAS CHANGED!” (SSH)**

  Clear the stale host key and pre-accept the current GitHub key:

  ```powershell
  ssh-keygen -R github.com
  ssh -o StrictHostKeyChecking=accept-new git@github.com
  ```

  Note: the generated `deploy_main.ps1` sets `GIT_SSH_COMMAND` to auto-accept host keys for future runs.

- **HTTPS push error: Invalid username or token**

  Enable Git Credential Manager and retry push to sign in via browser:

  ```powershell
  git config --global credential.helper manager-core
  cmd /c "cmdkey /delete:git:https://github.com" 2> NUL
  git push -u origin main
  ```

  Alternatively, switch to SSH (see next item).

- **Use SSH instead of HTTPS**

  Create an SSH key (once), add it to GitHub, test, then push:

  ```powershell
  if (-not (Test-Path "$env:USERPROFILE\.ssh\id_ed25519.pub")) { ssh-keygen -t ed25519 -C "you@example.com" }
  Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub" | Set-Clipboard  # paste into GitHub → Settings → SSH and GPG keys
  ssh -T git@github.com
  git remote set-url origin git@github.com:<your-username>/<your-repo>.git
  git push -u origin main
  ```

- **“protocol '.\\https' is not supported”**

  The remote URL was set with a mistaken prefix. Fix it:

  ```powershell
  git remote -v
  $URL = 'https://github.com/<your-username>/<your-repo>.git'
  git remote set-url origin $URL 2>$null; if ($LASTEXITCODE -ne 0) { git remote add origin $URL }
  git push -u origin main
  ```
