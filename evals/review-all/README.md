# review-all repeated-run eval

This eval runs the installed `review-all` skill several times against a small fixture repo. Then it measures how often each planted defect is found and how stable the results are across runs.

One run can pass by luck, so the eval repeats the review. Each run uses a headless `claude -p` session, because a subagent cannot start the subagents that `review-all` dispatches.

## Fixture

`build-fixture.sh <dir>` creates a git repo at `<dir>/repo` with three branches off `main`:

- `planted` contains 25 planted defects across security, reliability, observability, code, dependencies, agent config, accessibility, and `REVIEW.md` lenses.
- `control` contains the same files with the defects fixed.
- `empty` contains an empty commit.

The answer key is written beside the repo, not in it: `MANIFEST.md` for people and `MANIFEST.tsv` for `score.sh`.

All secrets, URLs, and module paths in the fixture are fake. `example.invalid` never resolves.

## Run

```sh
evals/review-all/run.sh <out-dir> [planted-runs] [control-runs]   # default 5 and 3
evals/review-all/score.sh <out-dir>
```

Each run takes several minutes and costs one full `review-all`, so 8 runs cost about 8 full reviews.

`run.sh` starts all runs in parallel. Each run uses its own clone and saves `stream.jsonl` (the headless event stream) and `SUMMARY.md`.

The fixture holds a hostile hook and an MCP config on purpose. So `run.sh` loads user settings only, turns off all hooks, loads no MCP servers, and blocks `WebFetch` and `WebSearch`. Runs use `bypassPermissions` because nobody is present to approve tool calls. Run the eval only on a machine where that is acceptable.

## Scoring

| Metric | Source | How it is scored |
|---|---|---|
| Per-defect hit rate | `SUMMARY.md` findings tables | A row cites the planted `file:line`, within 3 lines |
| Merged finding (P1-a) | `SUMMARY.md` | Exactly one row cites the line |
| Coverage row (P1-b) | `stream.jsonl` | A `COVERAGE` row marks the file `read-fully` or `skimmed` |
| Lens validation (P5-b, P5-c) | `## Not checked` | A line names the lens |
| Lens scoping (P5-d) | `stream.jsonl` | No subagent dispatched for the lens |
| Dispatch stability | `stream.jsonl` | Number of distinct sets of dispatched subagents per branch |
| Blocking verdict flips | Headline | Runs on one branch that disagree on blocking or clear |
| P0/P1 on control | `SUMMARY.md` | Rows with severity `CRITICAL` or `HIGH` |

The checks are text matches. A `0/n` for one defect is a lead to read the `SUMMARY.md`, not proof of a miss.

## Results

First measurement, 2026-11-26: 5 planted and 3 control runs, about $41 in total and 2 to 6 minutes per run.

- **Hit rate:** 24 of 25 planted defects were found in 5 of 5 runs. P1-a was found every time, but it was merged into one finding in only 3 of 5 runs. The 2 runs that kept two rows also skipped the summarizer subagent.
- **Dispatch:** the same 13 review domains and the `payments` lens ran in all 8 runs, and the `docs` lens never ran. The summarizer subagent ran in only 5 of 8 runs, although the skill requires it.
- **Verdicts:** no flips. All planted runs and all control runs are blocking.
- **Control:** 5 to 10 P0/P1 rows per run. Two causes:
  - The coverage reviewer rates missing tests as `CRITICAL` or `HIGH` and blocking.
  - The control branch still holds real defects that were not planted: an unresolvable `acme/widgets` dependency with fake `go.sum` hashes, `Valid("", "")` returning true, and retries with an empty idempotency key.

  Until the control branch is clean, the control verdict does not measure false positives.
