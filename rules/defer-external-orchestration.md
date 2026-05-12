# defer-external-orchestration

**Do not auto-execute timing-sensitive operations that depend on external state or sequencing.** Surface each step as a ready-to-run command and wait for the user to trigger.

Examples of operations that require user-triggered timing:

- Merging or queuing PRs (especially when behavior depends on sequencing, e.g. validating merge-queue batching, chained PRs, dependency order)
- Triggering deploys, releases, or rollbacks
- Draining traffic, scaling services, or toggling feature flags
- Running database migrations against shared environments
- Kicking off CI runs that gate other work, or re-running failed jobs to retry
- Posting webhooks, sending notifications, or triggering external integrations

Auto-execution is fine when the operation is **purely local and idempotent**: running tests, formatters, linters, generating code, editing local files.

When in doubt, present the command and ask. Wrong autonomous timing can cause batched merges, premature deploys, or skipped manual validation steps that the user needs in order to test a failure scenario.
