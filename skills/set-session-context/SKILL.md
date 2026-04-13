---
name: set-session-context
description: >-
  Use when starting a session on a non-main branch, switching branches
  (git checkout, git switch), or when a hook prompts for session context
  update. Also invocable manually via /set-session-context.
---

# Set Session Context

Automatically set session name and color based on the current git branch and PR.

## Steps

1. **Detect branch:**
   ```bash
   git symbolic-ref --short HEAD
   ```
   - If detached HEAD (command fails) → stop, do nothing
   - If `main` or `master` → stop, do nothing

2. **Look up PR title:**
   ```bash
   gh pr view --json title --jq '.title'
   ```

3. **Determine session name:**
   - If PR exists → use PR title
   - If no PR → humanize branch name: strip the conventional prefix and slash/hyphen separator, replace remaining hyphens with spaces
     - `feat/add-widget` → `add widget`
     - `fix-login-bug` → `login bug`

4. **Run:** `/rename <session name>`

5. **Determine color** from the branch prefix (match `^(type)[/-]`):

   | Prefix | Color |
   |---|---|
   | `feat` | blue |
   | `fix` | red |
   | `chore` | green |
   | `docs` | cyan |
   | `refactor` | yellow |
   | `test` | purple |
   | `ci` | orange |
   | `build` | orange |
   | `perf` | yellow |
   | `style` | cyan |
   | _(no match)_ | blue |

6. **Run:** `/color <color>`

## Behavior

- Execute silently — do not announce, explain, or narrate what you are doing.
- Do not ask for confirmation.
- If `gh` is unavailable or fails, fall back to the humanized branch name.
