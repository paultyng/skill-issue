# commit-per-phase

During multi-step or multi-file work, **commit at each completed phase** rather than accumulating everything into one final commit.

- A "phase" is any chunk of work the user has acknowledged as complete (per `confirm-before-implementing`), or any natural boundary: a feature, a refactor stage, a test pass, a config change.
- When phase N is confirmed complete, commit it **before** starting phase N+1.
- Commit before switching contexts (different file area, different abstraction layer) so a partial revert is possible without losing unrelated work.
- Each phase's commit uses Conventional Commits format (see `git-no-amend`). One phase = one commit; do not amend prior phases.
- If a single phase touches many files, that's still one commit — the unit is the phase, not the file count.

This makes review easier, makes reverts surgical, and prevents large "wall of changes" commits that bury intent.
