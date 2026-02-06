---
name: push
description: Review unpushed commits and push to remote
argument-hint: "[optional remote/branch]"
allowed-tools:
  - Bash
  - Read
---

# Git Push Skill

Review all unpushed commits, summarize them for the user, and push to the remote.

## Steps

1. Run these commands in parallel to understand the current state:
   - `git status` (never use `-uall` flag)
   - `git branch -vv` to see tracking branch and ahead/behind status
   - `git log @{u}..HEAD --oneline` to list unpushed commits (if upstream exists)
   - `git remote -v` to confirm remote URL

2. **Pre-push checks** — Before pushing, verify:
   - There is at least one unpushed commit. If none, inform the user and stop.
   - The current branch tracks a remote branch. If not, suggest setting upstream with `git push -u origin <branch>`.
   - There are no uncommitted changes that the user might want to include. If there are, warn the user and ask if they want to commit first.

3. **Summarize unpushed commits** — Show the user a clear summary:
   - Number of commits to push
   - List each commit (hash + message) in chronological order
   - The target remote and branch (e.g., `origin/main`)

4. **Security review** — Scan the full diff of unpushed commits (`git diff @{u}..HEAD`) for:
   - API keys or tokens (e.g. `sk-`, `Bearer`, hardcoded key strings)
   - Database files (`*.db`, `*.sqlite`, `*.sqlite3`)
   - Personal portfolio data (real dollar amounts, account numbers)
   - Credential files (`.env`, `*.pem`, `*.p12`, `*.key`, `credentials.*`)
   - App Group container data or UserDefaults plist exports
   - Any file under `~/Library/Application Support/` or `~/Library/Group Containers/`

   If anything suspicious is found, BLOCK the push and warn the user with specifics.

5. **Push** — Execute the push:
   - Default: `git push`
   - If `$ARGUMENTS` specifies a remote/branch, use that (e.g., `git push origin feature-branch`)
   - If no upstream is set, use `git push -u origin <current-branch>`

6. **Verify** — Run `git status` and `git log --oneline -3` to confirm the push succeeded and the branch is up to date with remote.

## Rules

- NEVER force push (`--force`, `-f`, `--force-with-lease`) unless the user explicitly requests it
- NEVER push to `main`/`master` with `--force` even if asked — warn the user instead
- NEVER use `--no-verify`
- If the push fails due to rejected updates (remote has new commits), suggest `git pull --rebase` first
- If the push fails for any other reason, show the error and suggest remediation
- Always confirm the remote URL looks correct before pushing (guard against typos or unexpected remotes)
