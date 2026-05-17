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
