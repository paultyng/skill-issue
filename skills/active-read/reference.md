# active-read: Reference

## Table of contents

- [Question typology](#question-typology)
- [Evaluation rubric](#evaluation-rubric) — populated in Task 10
- [Bad-question detector](#bad-question-detector) — populated in Task 10

## Question typology

Seven question types, all targeting Bloom levels above "knowledge" (recall is banned — anything Cmd-F-able is a bad question). The skill rotates types within a section; no doubling up.

| Type | Example phrasing | Bloom level | When to use | When NOT to use |
|---|---|---|---|---|
| Compare / pick | "When would you choose this over [obvious alternative]? When wouldn't you?" | evaluation | Trade-off-heavy material; competing options exist in or near the source | Single-method content; nothing meaningful to compare to |
| Predict failure | "What breaks first if X is 10× larger / smaller / removed?" | analysis | Scaling, robustness, fault-tolerance material; anything with implicit limits | Pure-definitional or terminology content |
| Find the trade-off | "What did the author give up to achieve property A?" | analysis | Material with explicit design choices and named properties | Survey / overview material without specific decisions |
| Apply to your stack | "Plug your service into this. Where does it fit? Where does it not?" | application | Architecture, framework, vendor product evaluations | Theoretical content with no concrete target system |
| Translate down | "Explain the core idea to a junior engineer in two sentences." | comprehension | Dense or jargon-heavy material; first-pass understanding check | Already-simple material; will collapse to paraphrase |
| Push back | "Where would you push back on this in a design review?" | evaluation | Opinionated, persuasive, or controversial material | Neutral reference docs / API surface |
| Why-not-the-obvious | "Why didn't they use [obvious mainstream tool / approach]?" | analysis | Custom or in-house solutions where mainstream alternatives exist | Greenfield problems with no mainstream alternative yet |

**Rule:** every question, regardless of type, must satisfy the bad-question detector (see below). If it fails any criterion, reject and re-pick.

## Evaluation rubric

Every grade has three parts. If you cannot fill all three honestly, the user's answer is too thin to evaluate — re-pose or push back, do not fabricate.

1. **What was right** — quote the specific phrase or claim from the user's answer that matches the source's argument.
2. **What was missing** — name the specific concept, caveat, or implication from the source that the user did not surface.
3. **Which passage to re-read** — point to the specific section, paragraph, or page where the missing piece lives.

### Worked example

**Source**: an architecture doc proposing a write-through cache fronting Postgres for a 10:1 read:write workload.

**Question (Compare / pick)**: "When would you choose write-through over write-behind here? When wouldn't you?"

**User answer**: "Write-through is safer because writes hit the DB immediately, so you don't lose data on cache failure."

**Evaluation:**

- **What was right**: "Write-through hits the DB immediately, so you don't lose data on cache failure" — yes, that captures the durability property.
- **What was missing**: the trade is *write latency*. The doc states a p99 write SLO of 50ms; write-through serializes user requests against DB latency, which write-behind would amortize. The user named only the safety side of the trade, not the cost.
- **Which passage to re-read**: section "Write path" → paragraph beginning "Each write blocks on..." — where the p99 SLO and the latency cost are stated explicitly.

## Bad-question detector

Before posing any question to the user, check it against three criteria. If the candidate matches **any**, reject and re-pick from the typology.

- **(a) Cmd-F-able** — could the user answer this by searching the source for a literal phrase? If yes, it's recall, not understanding. Examples: "What does the doc call the cache layer?" (find the name); "How many phases does the workflow have?" (count headings).
- **(b) Knowledge tier** — does the question target Bloom's "knowledge" level (definition recall, fact lookup, list reproduction)? Knowledge-tier questions are banned in active-read; the typology starts at "comprehension".
- **(c) Same type already asked** — has this question type already been posed in this section? Doubling up wastes the section's question budget; the rotation rule (in SKILL.md `### 3. Section loop`) forbids it.

If a question fails any criterion, do not pose it. Pick a different type or reword to target a higher Bloom level.
