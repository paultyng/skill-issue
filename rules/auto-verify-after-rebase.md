# auto-verify-after-rebase

After any rebase, merge, or cherry-pick, run full verification before pushing.

- Use the `verify-when-complete` workflow (fmt → lint → build → test).
- If buf/protoc is in the project, also run buf generate / buf lint.
- Do not push until all checks pass.
