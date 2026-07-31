---
name: simplify-prose
description: Use when writing or rewriting reader-facing technical text — documentation, READMEs, runbooks, procedures, error messages, release notes, incident reports, API guides, agent/system prompts — or when asked to "de-slop", "make this readable", "simplify this doc", "write for non-native readers", "apply STE", "Simplified Technical English", or "ASD-STE100", or to prepare text for translation. Also use to CHECK such text for clarity violations. Do NOT use for chat replies, PR/review comments, or commit messages (that is terse-output), nor for marketing, brand, or personal-voice writing (that is match-voice) — this skill deletes persuasion by design.
---

# Simplify Prose

Rewrite or check reader-facing technical text with the mechanical core of ASD-STE100 Simplified Technical English (STE), the controlled language aerospace and defense manufacturers use for maintenance manuals. The rules exist so a tired reader who is not a native English speaker cannot misread an instruction. They remove the usual signs of AI slop as a side effect: long sentences, synonym rotation, hedges, filler, decorative clauses.

Write for that tired reader. Each sentence must survive one read.

## Scope: where this skill applies

Scope-split with the `terse-output` rule:

- **This skill** owns reader-facing technical text (docs, READMEs, runbooks, error messages, release notes, incident reports, agent/system prompts). Keep **complete grammar** — articles, "that", no telegraph style, no contractions — for non-native readers.
- **`terse-output`** owns chat replies, PR/review comments, commit messages, where aggressive word-dropping is right.
- **`match-voice`** owns marketing, brand, and personal-voice writing. Do not apply this skill there; STE deletes persuasion by design (see Limit).

The modal ladder, slop substitutions, and condition-before-command are shared with `terse-output`. The completeness rules (keep articles, keep "that", no contractions) are this skill's alone.

## Workflow

1. **Classify** each passage as procedural or descriptive. Every other rule depends on this.
2. **Fix vocabulary before drafting.** Pick ONE verb for the check/verify/confirm concept and ONE noun for the config/settings concept. Use no other word for these concepts in the whole document.
3. **Apply the core rules** (below).
4. **Leave untouchables exact** — code, identifiers, commands, quoted errors.
5. **Run the self-check** before delivering. Not optional.

When asked to CHECK text instead of writing it, report each violation as: the offending text, the problem, a compliant rewrite. Use `references/checklist.md` for the searchable pass.

## Classify first

| | Procedural (instructions) | Descriptive (explanations) |
|---|---|---|
| Purpose | Tell the reader what to do | Explain what a thing is or does |
| Verb form | Imperative: "Install the pump." | Simple present / past / future |
| Sentence cap | **20 words** | **25 words** |
| Unit rule | One instruction per sentence | One topic per paragraph, max six sentences |

Do not mix the two in one passage. A "Getting started" section is procedural. An "Architecture" section is descriptive. A note inside a procedure is descriptive (25-word cap, no imperative).

## Core rules

**Sentence caps.** 20 words procedural, 25 descriptive. Backticked code, identifiers, numbers-with-units, and quoted text each count as **one word** toward the cap — long identifiers do not blow the budget. Over the cap → split into two sentences.

**Simple tenses only.** Use infinitive, imperative, simple present, simple past, simple future, and past participle as adjective ("the cached response"). No present perfect ("has completed" → "completed"). No `-ing` verb forms — an `-ing` word is legal only as a noun ("logging") or inside one, never as a verb ("making it easy" → new sentence).

**Active voice.** Passive is legal only in descriptive text when the agent is genuinely unknown.

**Modal ladder.** Approved: `can`, `will`, `must`. Replace `should`/`would`/`may`/`might`/`could` — see `references/substitutions.md`.

**Condition before command.** Lead with the condition, comma, then the action: "increase the timeout if the network is slow" → "if the network is slow, increase the timeout."

**Complete grammar.** This is the anti-terseness rule and the line against telegraph style. Keep articles (the/a/an), keep "that" after "make sure", expand contractions. STE is short sentences with *full* grammar, not telegram: "Ensure file exists before running" → "Make sure that the file exists before you run the command."

**One word, one meaning.** Pick one term per concept and hold it for the whole document. Collapse rotations: check/verify/confirm/validate → one; config/settings/options → one; run/execute/invoke → one. See `references/substitutions.md`.

**Slop → plain.** Delete or replace filler that carries no fact (leverage, utilize, robust, seamlessly, "in order to", "it is worth noting"). Full table in `references/substitutions.md`.

**Warnings first.** For a destructive action, put the command or condition first, then the risk: "Do not run `--force` against production. The flag deletes rows that do not match the source."

**No semicolons.** Write two sentences instead. Use a vertical list for more than two items or steps.

## Untouchables

Leave these exact, even when they break a vocabulary rule:

- Code blocks, inline code, identifiers, CLI commands, flags, file paths
- Quoted error messages and log lines
- Product names, API endpoint names, config keys
- Numbers with units (each counts as one word)

## Self-check before delivering

Not optional. Run these on the draft:

1. Count words in the three longest sentences. Over 20 (procedural) / 25 (descriptive) → split.
2. Search for: `'ll` `'re` `'s`-contraction, `has been`, `have been`, `should`, `, making`/`, allowing`/`, ensuring`, semicolons. Fix each.
3. Search every `if` and `when`. Each must stand at the START of its sentence, before the command, with a comma.
4. Search for the check/verify/confirm verbs you did NOT pick. Replace every hit with your chosen verb.

For a full audit, run `references/checklist.md`.

## Full example

**Before** (real AI output, ~40-word sentences, rotating verbs):

> If sqlpipe hangs or fails with `dial tcp: i/o timeout`, check that the host running sqlpipe can reach the Postgres port (usually 5432) — this is often a firewall rule blocking the connection. If you're connecting to a managed database (RDS, etc.), confirm the instance allows connections from sqlpipe's IP.

**After** (procedural, verb = "make sure", conditions first, one instruction per sentence):

> sqlpipe stops with `dial tcp: i/o timeout` when it cannot reach the Postgres port (5432 by default).
>
> 1. Make sure that the host that runs sqlpipe can reach the Postgres port. A firewall or security group usually blocks it.
> 2. If the database is managed (RDS, Cloud SQL), make sure that the instance accepts connections from the IP of sqlpipe.

Changed: sentences split under 20 words; "you're" expanded; "check"/"confirm" collapsed to "make sure that"; conditions moved before commands; "etc." removed; code and error strings untouched.

## Limit

STE is for technical facts and instructions. Do not apply it to marketing copy, blog voice, or personal-voice writing — it deletes persuasion by design. When asked to simplify such text, say so and hand off to `match-voice`, or offer STE for the docs instead.

This skill is an unofficial aid. It is not affiliated with or endorsed by ASD or STEMG, and no tool can guarantee STE compliance. ASD-STE100 is a registered trademark of ASD. The official standard is a free download at asd-ste100.org.

## References

- `references/checklist.md` — searchable verification pass for check mode and final audits
- `references/substitutions.md` — modal ladder, slop → plain table, one-word-one-meaning consistency sets

## Sources

Rules and examples adapted from the [SimpleEnglish](https://github.com/AminBlg/SimpleEnglish) skill by AminBlg, used under the [MIT License](https://github.com/AminBlg/SimpleEnglish/blob/main/LICENSE) (Copyright (c) 2026 AminBlg). SimpleEnglish paraphrases ASD-STE100 Issue 9; the official standard (with the ~900-word approved dictionary, not reproduced here) is a free download at asd-ste100.org.
