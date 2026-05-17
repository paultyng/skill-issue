# probe-not-assume

**Reading is hypothesis; probing is evidence.**

When working a hard problem — implementing, debugging, researching, planning, reviewing — do not accept the *appearance* of code, docs, or data as truth when you have the *means* to verify. Assumptions are debt; probing is how you cash them in. An agent that reads and concludes has only done half the job. The other half is running something that can fail.

Variants of the same principle:

- Appearance is hypothesis. Execution is evidence. Do not stop at the former.
- The program is the authority, not your model of it. When they conflict, the program wins.
- Every "this should work" is a debt. Pay it with a test, a grep, or a run.

## Failure modes

| Mode | What it looks like |
|---|---|
| Paraphrasing-instead-of-running | Agent summarizes what a function "should do" by reading and proceeds on the summary; never invokes it. |
| Shallow verification | Verification step checks `section present` / `file exists` / `string contained` rather than `section contains the right content`. Passes for any heading. |
| Library-API hallucination | Claims a method, flag, or constant exists without checking imports, docs, or the running language server. Confident wrong. |
| Schema guessing | Guesses field names or types from intuition rather than inspecting the actual schema (DDL, `.proto`, OpenAPI). |
| "This should work" without execution | Declares a fix correct after writing it; treats generation as verification. No test run, no output captured. |
| "Looks fine" review | Reviews a diff visually; finding is aesthetic. No grep, no test, no static analysis to back the claim. |
| Cascading false premise | Agent A emits a subtly wrong output; agent B receives it as ground truth; by the time a human notices, the wrong premise has propagated through multiple layers. |

## Antidotes

- **Write the failing test first.** A falsifiable, runnable hypothesis before any fix. The test failing now proves you're testing the right thing.
- **Make it fail first.** No fix attempt until you can reproduce on demand. (Agans Rule 2.)
- **Stimulate, don't simulate.** Trigger the real failure path; do not mentally replay it. (Agans.)
- **Instrument before guessing.** Add observability at the failing boundary — log, trace, metric — and let the data answer.
- **Grep before claiming.** Verifying a change means running the verification command, not visually inspecting the edit. Read the output.
- **Hypothesis → prediction → experiment.** Zeller/Regehr's scientific debugging loop. State the hypothesis, predict what an experiment would show, run it, update.
- **`git bisect`.** When a regression is in the search space, bisect divides it by half each step. Information-theoretically optimal.
- **The program is the authority.** When your mental model and the program disagree, the program wins. Update the model.

## Rationalization table

| Excuse | Reality |
|---|---|
| "It's obvious from reading the code." | Plenty of bugs survive close reading. Run it. |
| "Running it would take a minute." | Slow truth beats fast bullshit. Sixty seconds to know is cheap. |
| "I'd need to set up a repro environment." | That's the work; the absence of a repro environment is the bug to fix first. |
| "The diff is small; I can see what it does." | You can see what it *edits*; only the running program tells you what it *actually does*. |
| "I asked the LLM and it said yes." | Asking a model is reading another paraphrase. Run the actual thing. |
| "Adding logs would clutter the output." | Then observability is too thin. Add the log; fix the noise separately. |
| "Reviewing visually is faster than running tools." | Faster to a *result*, not to *truth*. The tool catches what eyes glide over. |

## When this rule fires

- Any task that ends with "DONE" or "complete" without a probed verification step.
- Any review finding without a `path:line` citation or command-output evidence.
- Any plan whose verification reads "section X present" instead of `grep -q ...`.
- Any answer that begins "this should work" or "this would work" without a run.
- Any cross-agent handoff where the receiving agent treats the upstream output as authoritative without independent probing.

Violating the letter of this rule IS violating its spirit. The whole rule is: when you have the means to confirm, use it.

## Sources

- David J. Agans, *Debugging: The 9 Indispensable Rules* (2002). Rules 2 ("Make it fail"), 3 ("Quit thinking and look"), 5 ("Change one thing at a time"), 9 ("If you didn't fix it, it ain't fixed").
- Andreas Zeller, *Why Programs Fail* (2005). Scientific debugging.
- John Regehr, "How to Debug". <https://blog.regehr.org/archives/199>.
- MIT 6.031, "Reading 13: Debugging". <https://web.mit.edu/6.031/www/sp21/classes/13-debugging/>.
- Charity Majors on observability-driven development.
