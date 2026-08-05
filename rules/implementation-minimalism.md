# implementation-minimalism

The best code is the code never written. Before adding code, climb the ladder to the **lowest rung that solves the problem**, and write the smallest diff that fully works.

This governs implementation *weight* — how much code the task takes. It complements `minimal-changes`, which governs *scope* — only doing what was asked. Different axes; apply both.

## The ladder

Climb from the top. Stop at the first rung that solves the problem; descend only when it genuinely doesn't. Name the rung when it's not obvious ("stdlib covers this", "reused existing `X`").

1. **Does it need to exist?** Reject speculative requirements and unused flexibility (YAGNI). The cheapest code is the code you didn't write.
2. **Already in this codebase?** Reuse an existing function, type, or pattern before writing a new one.
3. **Does the standard library, platform, or an already-installed dependency do it?** Prefer built-ins and existing deps over new code.
4. **Genuinely need a new dependency?** Defer to `evaluate-dependency` — it owns that decision (stdlib-first, canonical coordinate, tenure, maintenance). Don't re-ladder it here.
5. **Can it be smaller?** Prefer the smallest *clear* expression over a helper, wrapper, or abstraction. Fewest moving parts, not fewest characters — **clear beats clever**. If a one-liner reads worse than three plain lines, write the three.
6. **Otherwise, minimal patterns.** Fewest moving parts. No premature abstraction, no speculative interfaces, no configuration nobody asked for.

## Non-negotiables — MUST NOT cut these

Minimalism reduces *volume*, never *rigor*. These stay in full no matter how small the diff:

- **Input validation** on all untrusted input.
- **Error handling** — no swallowed, ignored, or blank-`_`'d errors on paths that can fail.
- **Security** — authn/authz checks, no injection surfaces, no secrets in code.
- **Accessibility** — semantic markup, labels, and keyboard paths for any UI.

A shorter solution that drops one of these is not minimal, it's broken. Never trade a non-negotiable for fewer lines.

## Anti-patterns

- A 20-line helper for what the stdlib does in one call.
- Adding a dependency to save a one-liner.
- A speculative interface with a single implementation. (An interface defined at the consumer for DI/mocking per `go-defaults` / `testing-philosophy` is not speculative — the test fake is its second implementation.)
- Config options, hooks, or generics nobody requested.
- "Might need it later" code — later can add it later.
- Code golf: a dense one-liner that reads worse than the plain version.
- Extracting a shared abstraction before it's earned — a little copying is better than a little dependency (or a premature abstraction). Default to the rule of three (≥3 call sites); abstract sooner only when the copies must stay in lockstep and would cause bugs if they drift.

## See also

- `minimal-changes` — scope (*what* to change); this rule — weight (*how much* code).
- `evaluate-dependency` — the dependency decision at rung 4 (stdlib-first, coordinate, tenure).
- `terse-comments` — the same restraint applied to comments.
- `probe-not-assume` — verify the minimal solution actually works; small is not correct by default.
