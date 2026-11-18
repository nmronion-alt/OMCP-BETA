# OMCP Panel Main — Library Backup

This repository is being prepared to hold the Library archive at:

`backups/OMCP-PANEL-main.zip`

## 1. Add the Library ZIP from your computer

Download `OMCP-PANEL-main.zip` from ChatGPT Library to your computer. Then, from PowerShell, run:

```powershell
git clone https://github.com/nmronion-alt/OMCP-BETA.git
cd OMCP-BETA
New-Item -ItemType Directory -Force backups | Out-Null
Copy-Item "$HOME\Downloads\OMCP-PANEL-main.zip" "backups\OMCP-PANEL-main.zip"
git add backups/OMCP-PANEL-main.zip
git commit -m "Add OMCP Panel Main library backup"
git push origin main
```

If the ZIP is saved somewhere else, replace the source path in `Copy-Item` with its actual path.

## 2. Verify the backup locally

Run from the repository root in Git Bash or WSL:

```bash
bash scripts/verify-library-backup.sh backups/OMCP-PANEL-main.zip
```

The script checks ZIP integrity and verifies that the archive contains the expected OMCP source files.

## 3. Verify that GitHub received it

After `git push` completes, run:

```bash
git ls-tree -r --long origin/main backups/OMCP-PANEL-main.zip
curl -fIL https://raw.githubusercontent.com/nmronion-alt/OMCP-BETA/main/backups/OMCP-PANEL-main.zip
```

The first command should show the ZIP in the remote Git tree. The second should return an HTTP success status.

To download the committed backup again:

```bash
curl -fL https://raw.githubusercontent.com/nmronion-alt/OMCP-BETA/main/backups/OMCP-PANEL-main.zip -o OMCP-PANEL-main-from-GitHub.zip
unzip -t OMCP-PANEL-main-from-GitHub.zip
```

## Important

The ZIP is a source-code backup, not a VPS data backup. It does not include live Minecraft worlds, server data under `/var/lib/omcp`, user databases, credentials, tunnel keys, or runtime backups unless those were explicitly present in the supplied ZIP.

Do not run the ZIP as an installer. First verify it, then inspect its README and installer instructions before using it on a VPS.
