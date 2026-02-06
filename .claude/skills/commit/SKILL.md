---
name: commit
description: Stage and commit changes with a well-crafted commit message
argument-hint: "[optional message hint]"
allowed-tools:
  - Bash
  - Read
---

# Git Commit Skill

Create a git commit for the current changes. If an argument is provided, use it as guidance for the commit message tone/content.

## Steps

1. Run these commands in parallel to understand the current state:
   - `git status` (never use `-uall` flag)
   - `git diff` and `git diff --cached` to see all changes
   - `git log --oneline -5` to match existing commit message style

2. **Security review** — Before staging, scan the diff for leaked secrets or personal data. BLOCK the commit and warn the user if any of the following appear in changed lines:
   - API keys or tokens (e.g. `sk-`, `Bearer`, hardcoded key strings)
   - Database files (`*.db`, `*.sqlite`, `*.sqlite3`)
   - Personal portfolio data (real dollar amounts, account numbers, asset quantities that look like real user data rather than code logic)
   - Credential files (`.env`, `*.pem`, `*.p12`, `*.key`, `credentials.*`)
   - App Group container data or UserDefaults plist exports
   - Any file under `~/Library/Application Support/` or `~/Library/Group Containers/`

3. Analyze all staged and unstaged changes. Draft a commit message that:
   - Summarizes the nature of changes (new feature, bug fix, refactor, etc.)
   - Is concise (1-2 sentences) and focuses on "why" not "what"
   - Matches the repository's existing commit style
   - If `$ARGUMENTS` was provided, incorporate that guidance

4. Stage the relevant files by specific filename (NEVER use `git add -A` or `git add .`). Skip any file that fails the security review.

5. Create the commit using a HEREDOC for the message:
   ```
   git commit -m "$(cat <<'EOF'
   Your commit message here.

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   EOF
   )"
   ```

6. Run `git status` after committing to verify success.

## Sensitive Files — NEVER Stage These

- `*.db`, `*.sqlite`, `*.sqlite3` — contains personal portfolio/financial data
- `.env`, `*.pem`, `*.p12`, `*.key` — secrets and certificates
- `credentials.*`, `*secret*`, `*token*` — credential files
- `*.plist` from Group Containers or Application Support
- Any file matching patterns in `.gitignore`

If any of these are in the changeset, explicitly tell the user which files were skipped and why.

## Rules

- NEVER amend existing commits unless explicitly told to
- NEVER force push
- NEVER use `--no-verify`
- If a pre-commit hook fails, fix the issue, re-stage, and create a NEW commit
- When in doubt about whether a file contains sensitive data, ask the user before staging
