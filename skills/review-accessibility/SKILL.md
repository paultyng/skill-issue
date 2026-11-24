---
name: review-accessibility
description: Use when the user asks for an accessibility review, a11y audit, WCAG review, screen-reader or keyboard-navigation check, ARIA review, or color-contrast check, or reviews UI components (JSX, TSX, Vue, Svelte, HTML templates, CSS), or when another skill dispatches an accessibility review.
---

# Accessibility Review

Static review of UI source against WCAG 2.1. Every finding cites a success criterion (SC) and takes its severity from that SC's conformance level.

## Scope

In-scope extensions: `.tsx` `.jsx` `.vue` `.svelte` `.astro` `.html` `.hbs` `.ejs` `.pug` `.erb` `.njk` `.css` `.scss` `.sass` `.less`.

- **Changed files (PR or branch):** `git diff --name-only --diff-filter=d <base>...HEAD` (default `<base>` is `main`), or `gh pr diff <number> --name-only`. Filter to the extensions above.
- **Explicit paths:** include every in-scope file under each path.
- **Full codebase:** every in-scope file.

If no in-scope file exists, report that and stop. Reading is not scoped: follow imported components, design-system wrappers, and shared styles when a finding depends on them. Prefix defects in code the scope uses but did not change with `pre-existing:`.

## Severity

| WCAG level | Severity | Blocking default |
|---|---|---|
| A | P1 | y |
| AA | P2 | n |
| AAA | P3, only when the user asks for AAA | n |

Severity comes from the SC's level, not from how bad the defect looks. Missing `alt` on an informative image is 1.1.1 (Level A), so it is P1. Each check in [reference.md](reference.md) lists its SC and level.

## Rules

- **Cite the SC** by number and name in every finding: `1.1.1 Non-text Content`. A finding without one is not a finding.
- **`rule_id`** is the SC in kebab form: `wcag-1.1.1`, `wcag-2.1.1`, `wcag-4.1.2`.
- **Contrast you cannot compute statically is `manual testing needed`.** Colors from theme tokens, CSS variables, `currentColor`, props, or runtime state (hover, disabled, dark mode) get no pass/fail verdict. Compute and report only when both foreground and background are literal values in scope (4.5:1 normal text, 3:1 large text and UI components).
- **Check the component library before flagging.** A `<Dialog>`, `<Button>`, or `<Menu>` from Radix, Headless UI, React Aria, MUI, Chakra, Reach, Vuetify, or a local design system often supplies role, keyboard handling, focus trap, and ARIA. Read the wrapper source or its docs in `node_modules`. Flag only what the library leaves to the caller (an accessible name, a label, `alt`).
- **First rule of ARIA:** recommend the native element (`<button>`, `<a href>`, `<input type="checkbox">`) before adding `role` and handlers to a `<div>`.
- **Stay in the accessibility lane.** Type errors, state bugs, missing features, and styling preferences go nowhere in this report. Other review-* skills own them.
- **Static review only.** Do not claim screen-reader or keyboard behavior you did not trace in code. When behavior depends on runtime (focus after route change, live-region timing), mark `conf=low` or list it under **Manual testing needed**.
- **Low confidence never blocks.** A `conf=low` finding is `blocking=n`, whatever its level.
- **Name vs. visible label.** `aria-label` or `aria-labelledby` satisfies 4.1.2; do not raise 4.1.2 or 1.3.1 for it. Raise 3.3.2 only when no visible label or instruction exists (placeholder-only, or `aria-label` with nothing on screen), and say which.

## Workflow

1. Resolve scope to a file list.
2. Identify the component library and styling system (`package.json`, imports, theme files).
3. Read each in-scope file fully. Walk the checks in [reference.md](reference.md) by principle.
4. For each candidate defect, confirm the library does not already handle it.
5. Emit findings and coverage rows in the format below.

## Output

Resolve `REVIEW_DIR` as the review-all orchestrator passes it, else `.reviews/$(date +%Y-%m-%d)` (append `-$(date +%H%M)` if it exists; run `~/.claude/scripts/ensure-gitignore.sh '.reviews/'`). Write `${REVIEW_DIR}/ACCESSIBILITY-REVIEW.md`, then present it.

Prefix each finding with one header line, and list one coverage row per in-scope file after the findings:

```
FINDING | rule_id=<id> | sev=<P0-P3> | blocking=<y|n> | conf=<high|med|low> | dkey=<path>:<line>:<rule_id>
COVERAGE | file=<path> | status=<read-fully|skimmed|not-read>
```

Example:

```
FINDING | rule_id=wcag-1.1.1 | sev=P1 | blocking=y | conf=high | dkey=src/Avatar.tsx:12:wcag-1.1.1
src/Avatar.tsx:12 — `<img src={url}>` has no `alt`. 1.1.1 Non-text Content (A). Add `alt={user.name}`, or `alt=""` if decorative.
COVERAGE | file=src/Avatar.tsx | status=read-fully
```

Report sections, in order:

1. Scope (file list, component library detected)
2. Tool availability: static review; no axe, Lighthouse, contrast checker, or screen reader ran
3. Findings table: Severity | SC | Finding (`path:line`, defect, fix) | Tracked
4. Manual testing needed: contrast from tokens or runtime state, behavior that needs a browser or screen reader
5. Coverage rows

When `pr_url` is set, wrap `path:line` with `~/.claude/scripts/pr-deeplink.sh "$pr_url" <path> <line>`. If a `REVIEW.md` exists, apply its rules and "Skip" patterns.

## Rationalizations

| Excuse | Reality |
|---|---|
| "Missing alt text is medium severity." | 1.1.1 is Level A. Level A is P1. |
| "The fix is obvious; the SC number is noise." | The SC is the evidence and sets the severity. Cite it. |
| "While I'm here, the missing type import and overflow restore are worth flagging." | Not accessibility. Leave them out. |
| "The colors look fine." | If they come from tokens or variables, report `manual testing needed`. Never pass or fail them. |
| "This `<Dialog>` has no focus trap." | Check the library first. Radix, Headless UI, and React Aria dialogs trap and restore focus. |
| "Add `role="button"` and `tabIndex={0}` to the div." | Use `<button>`. Native elements bring keyboard and semantics for free. |

## Red flags

- A finding with no SC number.
- A severity that disagrees with the SC's level.
- A pass or fail on a contrast whose colors are not both literal values.
- A flagged dialog, menu, or tab set with no check of the component source.
- Any finding about types, state, logic, or features.
- An in-scope file with no `COVERAGE` row.

## Sources

- [WCAG 2.1](https://www.w3.org/TR/WCAG21/), W3C Recommendation. W3C Document License.
- [WAI-ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/), W3C. W3C Document License.
- [Using ARIA](https://www.w3.org/TR/using-aria/), W3C. W3C Document License.
