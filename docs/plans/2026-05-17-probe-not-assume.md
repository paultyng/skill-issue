# probe-not-assume rule + cascade

Implementation plan for a new discipline rule `probe-not-assume` (lead sentence: "Reading is hypothesis; probing is evidence") plus a cascade of one-line cross-references and small Guidelines additions across `implement-plan`, all `review-*` skills, and the analysis/verification skills. The principle: assumptions are unnecessary when we have the means to confirm; an agent that reads and concludes has only done half the work.

## Branch policy

- Branch: feat/probe-not-assume-rule
- Base: origin/main

## Goal

Reduce agentic failure modes documented in the literature: paraphrasing-instead-of-running, shallow verification ("section present" passes for anything), library-API hallucination, schema guessing, "this should work" without execution, "looks fine" review, cascading false premise. The rule is the canonical reference; skills cross-reference it rather than each restating the principle.

## Definition of Done

- `~/.claude/rules/probe-not-assume.md` exists with: lead sentence (the seed quote, bold), ≥3 phrasing variants, "Failure modes" table with ≥6 rows, "Antidotes" list with ≥6 entries, "Rationalization table" with ≥5 excuse→reality rows.
- `implement-plan` SKILL.md and reference.md both cross-reference the rule; implementer-template instructions include "probe before claiming DONE".
- `review-plan` SKILL.md plan-shape contract requires probable verification steps (grep / run / output), not presence-checks.
- All 12 domain review-* skills (review-code, review-coverage, review-database, review-documentation, review-reliability, review-security, review-infrastructure, review-ci, review-observability, review-api-compat, review-performance, review-all) have a Guidelines bullet + cross-ref.
- 5 analysis skills (evaluate-dependency, bisect, ci-debug-loop, analyze-knowledge, discover-patterns) cross-reference the rule.
- `verify-when-complete` cross-references the rule.
- Final smoke test: `grep -rl 'probe-not-assume' ~/.claude/skills ~/.claude/rules | wc -l` returns ≥ 21 (1 rule + escalation cross-ref + 2 implement-plan + 1 review-plan + 12 review-* + 5 analysis + 1 verify-when-complete = 23 expected; allow margin for combined-files counts).

## Constraints

- Cross-references are one-line additions; do NOT rewrite skill bodies.
- Each task's verification step is itself a probable check (grep / wc / run), per the principle we're enshrining. No "section present" verifications.
- Do NOT touch the active-read plan in this branch (it lives on `feat/active-read-skill` and will be updated when active-read is resumed).
- Rule file follows existing convention: simple markdown, ≤200 lines, single-purpose.

## Tasks

- [x] **Task 1: Write the rule file.** Create `~/.claude/rules/probe-not-assume.md` with: H1 title, lead sentence ("**Reading is hypothesis; probing is evidence.**"), 3 phrasing variants below, "## Failure modes" table with ≥6 rows (paraphrasing-instead-of-running, shallow verification, library-API hallucination, schema guessing, "this should work" without execution, "looks fine" review, cascading false premise — pick 6+), "## Antidotes" bullet list with ≥6 items (write the failing test, instrument before guessing, git bisect, grep before claiming, hypothesis-prediction-experiment, "make it fail first" per Agans, "stimulate don't simulate", "the program is the authority"), "## Rationalization table" with ≥5 excuse→reality rows. Files: `rules/probe-not-assume.md`. Verify (run from ~/.claude): `[ $(wc -l < rules/probe-not-assume.md) -le 200 ] && echo OK` prints `OK`; `grep -cF '**Reading is hypothesis; probing is evidence' rules/probe-not-assume.md` returns 1; `grep -c '^| ' rules/probe-not-assume.md` returns ≥ 11 (≥6 failure-mode rows + ≥5 rationalization rows + headers).

- [ ] **Task 2: Cross-ref from escalation rule.** Append a one-line cross-ref to `~/.claude/rules/escalation.md`: when escalation feels heavy and you're tempted to invent a "reasonable default" instead, that's a probe-not-assume violation; the rule is more authoritative than your discomfort. Files: `rules/escalation.md`. Verify: `grep -c 'probe-not-assume' rules/escalation.md` returns 1.

- [ ] **Task 3: Update implement-plan SKILL.md.** In the per-task loop section (Step 4), add an explicit sub-bullet to the implementer-subagent step: "Implementer must probe before claiming DONE — run the verification command, grep for the expected change, do not paraphrase 'should work' as evidence. Per `~/.claude/rules/probe-not-assume.md`." Add one row to the Cross-references section pointing to the new rule. Files: `skills/implement-plan/SKILL.md`. Verify: `grep -c 'probe-not-assume' skills/implement-plan/SKILL.md` returns ≥ 2 (the inline reference + the cross-references section); `grep -q 'probe before claiming' skills/implement-plan/SKILL.md`.

- [ ] **Task 4: Update implement-plan reference.md.** In the "Reviewer prompt template" → "Constraints", add: "Findings must cite probed evidence (`path:line` + grep output + command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`." In "Red flags", add: "Marking task DONE based on visual inspection of the edit rather than running the verification command (probe-not-assume violation)." In "Rationalization table", add one row: `"Verification command would slow me down" → "Slow is the price of true. DONE without probe is a probe-not-assume violation."`. Files: `skills/implement-plan/reference.md`. Verify: `grep -c 'probe-not-assume' skills/implement-plan/reference.md` returns ≥ 3; `grep -q 'probed evidence' skills/implement-plan/reference.md`; `grep -q 'visual inspection of the edit' skills/implement-plan/reference.md`.

- [ ] **Task 5: Update review-plan SKILL.md plan-shape contract.** In Step 3's table, change the "verification step" row to require a probable check (greppable string, command with expected output, or file-content assertion); add a sentence in Guidelines: "Verification steps in tasks must be probable (run/grep/output), not presence-checks. Per `~/.claude/rules/probe-not-assume.md`." Files: `skills/review-plan/SKILL.md`. Verify: `grep -c 'probable' skills/review-plan/SKILL.md` returns ≥ 1; `grep -c 'probe-not-assume' skills/review-plan/SKILL.md` returns ≥ 1.

- [ ] **Task 6: Cascade to 12 domain review-* skills.** Add to each one's Guidelines section a single bullet: "- Findings must cite probed evidence (`path:line`, grep output, command result), not pattern-matched suspicion. Per `~/.claude/rules/probe-not-assume.md`." Files: `skills/review-code/SKILL.md`, `skills/review-coverage/SKILL.md`, `skills/review-database/SKILL.md`, `skills/review-documentation/SKILL.md`, `skills/review-reliability/SKILL.md`, `skills/review-security/SKILL.md`, `skills/review-infrastructure/SKILL.md`, `skills/review-ci/SKILL.md`, `skills/review-observability/SKILL.md`, `skills/review-api-compat/SKILL.md`, `skills/review-performance/SKILL.md`, `skills/review-all/SKILL.md`. Verify: `grep -l 'probe-not-assume' skills/review-{code,coverage,database,documentation,reliability,security,infrastructure,ci,observability,api-compat,performance,all}/SKILL.md | wc -l` returns 12; combined with review-plan from Task 5, `grep -l 'probe-not-assume' skills/review-*/SKILL.md | wc -l` returns 13.

- [ ] **Task 7: Cascade to 5 analysis skills.** Add a one-line cross-ref to each in an appropriate Guidelines/Notes section: "Per `~/.claude/rules/probe-not-assume.md`: confirm via tool/command before recommending; do not infer." Files: `skills/evaluate-dependency/SKILL.md`, `skills/bisect/SKILL.md`, `skills/ci-debug-loop/SKILL.md`, `skills/analyze-knowledge/SKILL.md`, `skills/discover-patterns/SKILL.md`. Verify: `for f in evaluate-dependency bisect ci-debug-loop analyze-knowledge discover-patterns; do grep -q 'probe-not-assume' "skills/$f/SKILL.md" || echo "MISSING: $f"; done` produces no MISSING lines.

- [ ] **Task 8: Update verify-when-complete cross-ref.** Add a one-line note near the top of verify-when-complete's workflow body: "This skill is the operational arm of `~/.claude/rules/probe-not-assume.md`: claims of completion require fresh, probed evidence, not implementer self-report." Files: `skills/verify-when-complete/SKILL.md`. Verify: `grep -c 'probe-not-assume' skills/verify-when-complete/SKILL.md` returns ≥ 1; `grep -q 'operational arm' skills/verify-when-complete/SKILL.md`.

- [ ] **Task 9: Smoke test — cross-references land everywhere.** Run `COUNT=$(grep -rl 'probe-not-assume' ~/.claude/skills ~/.claude/rules | wc -l)` and confirm `$COUNT` ≥ 21. Append a `## Test result` section to THIS plan file containing (a) the literal line `Cross-reference count: N` where N is the observed count; (b) the literal line `Files referencing the rule:` followed by the bullet-list output of `grep -rl 'probe-not-assume' ~/.claude/skills ~/.claude/rules | sort`. Files: `docs/plans/2026-05-17-probe-not-assume.md`. Verify: `grep -c '^## Test result' docs/plans/2026-05-17-probe-not-assume.md` returns 1; `grep -E '^Cross-reference count: [0-9]+' docs/plans/2026-05-17-probe-not-assume.md` matches a line with N ≥ 21; `grep -c '^- /' docs/plans/2026-05-17-probe-not-assume.md` returns ≥ 21 (one bullet per referencing file); `grep -c '^- \[ \]' docs/plans/2026-05-17-probe-not-assume.md` returns 0 (all task boxes ticked).
