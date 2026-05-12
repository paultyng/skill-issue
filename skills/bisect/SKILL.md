---
name: bisect
description: Use when hunting a regression, phrases like "bisect", "find the commit that broke X", "this used to work", "regression in test Y", "when did <symptom> start". Also use when escalated from ci-debug-loop because log analysis can't pinpoint the offending change, or when a previously-passing test/build/behavior is now failing and the cause isn't obvious from the recent diff. Drives `git bisect run` against a user-provided reproducer command, isolates the offending commit, and reports it with diff and metadata. Does not auto-fix.
---

# Bisect

Drive `git bisect` to isolate the first commit that introduced a bug, then report it. The skill stops at the report. Fixing belongs to the user with full context.

## When to use

- User asks to "bisect", "find the commit that broke X", says "this used to work", or names a regression in a specific test/build target.
- `ci-debug-loop` exhausted log analysis without identifying a clear cause.
- A behavior, test, or build that was green at a known earlier point is now red.

Do **not** use when the bug is obviously in the most recent commit (inspect it), or when the reproducer is too fragile/flaky to drive an automated bisect (fix the flake first).

## Inputs (confirm before starting)

Per `confirm-before-implementing`, gather these before touching `git bisect`:

- **Symptom**: one-line description of what's broken (e.g. "TestExchangeToken fails with `unauthorized`").
- **Reproducer**: a shell command that exits 0 when the bug is absent, 1 when present. If the user can't supply one, build it together (see [Reproducer strategy](#reproducer-strategy)).
- **Known-bad ref**: default `HEAD`.
- **Known-good ref**: default oldest commit within the last 2 weeks:
  ```sh
  git rev-list --since='2 weeks ago' --reverse HEAD | head -1
  ```
  If the user has a tag, branch, or specific date in mind, use it instead.

## Reproducer strategy

The reproducer must work at *every* commit in the bisect range. The reproducer that exists today often won't: APIs change, test files don't yet exist on old commits, etc. Pick the highest-applicable strategy:

1. **External reproducer (preferred).** A self-contained shell script in `$TMPDIR` (e.g. `/tmp/repro.sh`) that builds and exercises the project from outside the source tree. Hits a stable surface (CLI flag, HTTP endpoint, exported function with stable signature) that survived the bisect range. Examples:
   ```sh
   # CLI: build and check observable behavior
   go build -o /tmp/foo ./cmd/foo && /tmp/foo --some-flag | grep -q expected
   # HTTP: spin up server, hit endpoint, kill
   go run ./cmd/server & PID=$!; sleep 1; curl -fsS localhost:8080/health; kill $PID
   ```
   This survives any in-tree changes because the reproducer doesn't live in the tree.

2. **Carry an in-tree reproducer file** across checkouts. Stash the reproducer test file, `git stash apply` it at each step, run, undo. Workable but brittle; checkouts during bisect can conflict with the stash. Use only when an external reproducer is impossible.

3. **Narrow the range first.** If the reproducer fundamentally requires an API that didn't exist before commit X, set the known-good to X and bisect within the API-stable window. The bisect then can't find regressions older than X. Accept that as a scope limit, don't fight it.

If none of the three apply, bisect is the wrong tool. Read the diff manually instead.

## Workflow

1. **Resolve refs and reproducer.** Confirm the reproducer exits 1 at HEAD (bug present) and 0 at known-good (bug absent). If either fails, the inputs are wrong. Stop and re-gather.

2. **Estimate cost.** Count commits in range:
   ```sh
   git rev-list --count <good>..<bad>
   ```
   Steps ≈ `log2(N)`. If more than ~8 steps (>256 commits), ask the user to narrow the known-good; bisect time grows quickly.

3. **Snapshot working state.** Auto-stash uncommitted changes including untracked files:
   ```sh
   STASH_REF=""
   if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
     git stash push -u -m "bisect-auto-$(date +%s)" && STASH_REF=$(git rev-parse stash@{0})
   fi
   ORIG_HEAD=$(git rev-parse --abbrev-ref HEAD)
   trap 'git bisect reset >/dev/null 2>&1; git checkout "$ORIG_HEAD" 2>/dev/null; [ -n "$STASH_REF" ] && git stash pop 2>/dev/null' EXIT INT TERM
   ```
   The trap restores state on success, error, or interrupt.

4. **Build the wrapper script.** Write to `$TMPDIR/bisect-wrapper.sh`:
   ```sh
   #!/bin/sh
   set -e

   # Skip commits explicitly marked as intentionally broken.
   if git log -1 --format=%B | grep -qF '[skip-bisect]'; then
     exit 125
   fi

   # Optional project regen, uncomment per project needs.
   # task generate || exit 125
   # buf generate || exit 125

   # Run the reproducer. Exit 0 = good, 1 = bad, 125 = skip.
   <USER REPRODUCER COMMAND HERE>
   ```
   `chmod +x` the wrapper. Compile errors and missing-tool failures from the reproducer should propagate as exit codes the wrapper passes through; commits that can't even build typically return non-zero from the build step. Convert those to 125 by guarding with `|| exit 125` if the user wants to skip them rather than treat them as bad.

5. **Run bisect.**
   ```sh
   git bisect start <bad> <good>
   git bisect run "$TMPDIR/bisect-wrapper.sh"
   ```
   `git bisect run` drives to completion automatically. Capture the output.

6. **Read the result.** The last line of `git bisect run` output is `<sha> is the first bad commit`. Capture the SHA:
   ```sh
   FIRST_BAD=$(git bisect log | awk '/first bad commit/ {print $2}' | head -1)
   ```
   If `git bisect log` doesn't have it (older git), parse the run output instead.

7. **Reset state.** `git bisect reset` returns HEAD to the original ref. The trap will fire on exit and restore the stash.

8. **Generate report** (see [Output](#output)).

## Edge cases

- **Flaky reproducer.** If the same commit returns different exit codes on repeat runs, bisect is unreliable. Loop the reproducer N times (e.g. 5) and treat *any* failure as bad. Wrap the user's command in `for i in 1 2 3 4 5; do <repro> || exit 1; done; exit 0`. If still flaky, fix the flake first.
- **Stale generated files** after `git checkout` between steps. Add a regen step at the top of the wrapper (`task generate`, `buf generate`, `npm run generate`) before the reproducer.
- **`[skip-bisect]` commits.** Wrapper greps the message and exits 125. This relies on the `commit-per-phase` rule's marker convention; assume well-formed history.
- **Compile/setup failures** on old commits often surface as non-zero exits. By default `git bisect run` treats those as "bad". If they're really "can't tell", convert to 125 by guarding setup with `|| exit 125` in the wrapper.
- **Working tree dirt.** Handled by step 3's auto-stash + trap. Don't skip the trap; Ctrl-C without it leaves the user mid-bisect.
- **Merges in the range.** `git bisect` handles them by linearizing via the commit graph. No special action.
- **Refactor renames.** The offending commit may be a rename or move that exposes a latent bug elsewhere. Note this in the report; don't claim the rename is the root cause.

## Output

Produce a single Markdown report:

```markdown
## Offending commit
**<sha7>** — <subject>
Author: <name> | Date: <YYYY-MM-DD>
PR: <url if found via `gh pr list --search "<sha>" --state merged`>

## Diff
<output of `git show --stat <sha>` followed by `git show <sha>`>

## Commit message
<full body from `git log -1 --format=%B <sha>`>

## Suggested next step
- [ ] Write a regression test that reproduces <symptom> at HEAD (so the bisect is repeatable)
- [ ] Revert + reimplement, OR fix forward (user's call)
- [ ] Open issue / PR comment if the offending commit was already merged and shipped
```

Do **not** auto-revert, auto-fix, or push anything. The skill ends at the report.

## Cross-references

- `commit-per-phase` rule defines the `[skip-bisect]` marker the wrapper looks for.
- `ci-debug-loop` skill is the typical escalation source. When log analysis stalls, hand the failing test/command to this skill as the reproducer.
- `verify-when-complete` skill produces good reproducer one-liners (`task test -- -run '^TestX$'`).

## Anti-patterns

- Running bisect without a deterministic reproducer. Guesses propagate exponentially.
- Skipping the auto-stash and trap. Leaves the user mid-bisect on Ctrl-C.
- Treating compile-error commits as "bad" without checking. That's a setup failure, not the bug.
- Auto-fixing the offending commit. Out of scope for this skill.
