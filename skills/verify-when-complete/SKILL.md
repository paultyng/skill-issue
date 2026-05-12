---
name: verify-when-complete
description: Run format, lint, build, and test verification before claiming work is complete. Detects the project toolchain (Taskfile, Makefile, or raw Go) and runs the appropriate commands. Use before committing, pushing, creating PRs, claiming a fix works, or any completion assertion.
---

# Verify When Complete

No completion claims without fresh verification evidence.

## Core Principle

Evidence before claims, always. If you haven't run the verification command in this message, you cannot claim it passes.

## Gate Rule

Before claiming any status or expressing satisfaction:

1. **Identify**: What command proves this claim?
2. **Run**: Execute the full command (fresh, complete)
3. **Read**: Full output, check exit code, count failures
4. **Verify**: Does output confirm the claim?
   - If NO: state actual status with evidence
   - If YES: state claim with evidence
5. **Only then**: make the claim

## Red Flags: Stop and Verify

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Done!")
- About to commit/push/PR without verification
- Relying on a previous run, not a fresh one
- Trusting subagent success reports without independent verification

## Detected Toolchain

!`if [ -f Taskfile.yaml ]; then echo "taskfile"; elif [ -f Makefile ]; then echo "makefile"; else echo "raw"; fi`

Use the detected toolchain above to select commands from the tables below.

## Verification Steps

Run each step in order. If any step fails, stop and report the error.

### Format

| Toolchain | Command |
|-----------|---------|
| Taskfile | `task fmt` (if exists) |
| Makefile | `make fmt` (if exists) |
| Raw Go | `go fmt ./...` |

### Lint

| Toolchain | Command |
|-----------|---------|
| Taskfile | `task lint` (if exists) |
| Makefile | `make lint` (if exists) |
| Raw Go | `go vet ./...` |

### Build

| Toolchain | Command |
|-----------|---------|
| Taskfile | `task build` (if exists) |
| Makefile | `make build` (if exists) |
| Raw Go | `go build ./...` |

### Test

| Toolchain | Command |
|-----------|---------|
| Taskfile | `task test` (if exists) |
| Makefile | `make test` (if exists) |
| Raw Go | `go test -race -count 1 -v ./...` |

If a specific task/target doesn't exist, fall back to the raw Go equivalent. Run tests uncached (`-count 1`), with race detection, no `-short` flag.

## When to Apply

- Before committing or pushing
- Before creating or updating a pull request
- Before claiming a bug is fixed
- Before claiming a rebase or conflict resolution succeeded
- Before moving to the next task after making changes
- Before any statement asserting correctness or completion

## Cross-references

- The narrowest verification command this skill produces (e.g. `task test -- -run '^TestX$' -count=1`) is the natural reproducer for the `bisect` skill. When a test that this skill once green-lit is now red, bisect with that exact command.
