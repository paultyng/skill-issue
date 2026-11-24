# Accessibility Checks

One line per check: defect → fix (SC, level). Severity: A → P1, AA → P2, AAA → P3 (only when asked).

## Contents

- [Perceivable](#perceivable)
- [Operable](#operable)
- [Understandable](#understandable)
- [Robust](#robust)
- [Widget patterns](#widget-patterns)
- [Sources](#sources)

## Perceivable

- `<img>`, `<input type="image">`, `<area>` without `alt` → add `alt` text; `alt=""` if decorative (1.1.1, A).
- Icon-only button or link (SVG, icon font) with no text → add `aria-label` or visually hidden text; mark the icon `aria-hidden="true"` (1.1.1, A; 4.1.2, A).
- Informative `<svg>` without `role="img"` and `<title>` or `aria-label` → add both (1.1.1, A).
- `alt` that repeats adjacent text, or reads "image of" / a filename → shorten to the purpose, or `alt=""` (1.1.1, A).
- `<video>` with speech and no `<track kind="captions">` → add captions (1.2.2, A).
- Prerecorded audio-only or video-only with no transcript or description → add one (1.2.1, A).
- Heading styled with a `<div>` / bold `<span>` → use `<h1>`–`<h6>` in order (1.3.1, A).
- List, table, or form group built from `<div>`s → use `<ul>`/`<ol>`, `<table>` with `<th scope>`, `<fieldset>`/`<legend>` (1.3.1, A).
- Layout table without `role="presentation"` → add it, or replace with CSS (1.3.1, A).
- DOM order differs from visual order (CSS `order`, absolute positioning, `flex-direction: row-reverse`) so reading order breaks → reorder the DOM (1.3.2, A).
- Instruction relies only on shape, position, or color ("click the green button") → add a text label (1.3.3, A).
- Input for user data (name, email, address) without `autocomplete` → add the matching token (1.3.5, AA).
- Color is the only signal for state, error, required, or link vs text → add text, icon, or underline (1.4.1, A).
- Text contrast below 4.5:1 (3:1 for ≥24px or ≥18.66px bold), both colors literal → raise contrast (1.4.3, AA).
- Contrast from tokens, CSS variables, `currentColor`, props, or hover/disabled/dark state → list under **Manual testing needed**; no verdict (1.4.3, AA; 1.4.11, AA).
- Font size in `px` on `html`/`body`, or `maximum-scale=1` / `user-scalable=no` in viewport meta → use relative units; remove zoom lock (1.4.4, AA).
- Text rendered as an image → use real text (1.4.5, AA).
- Fixed-width container that forces horizontal scroll at 320 CSS px → make it responsive (1.4.10, AA).
- Focus ring, input border, or icon below 3:1 against adjacent color, both literal → raise contrast (1.4.11, AA).
- Fixed `height` with `overflow: hidden` on text containers → allow growth under increased spacing (1.4.12, AA).
- Hover/focus tooltip that cannot be dismissed with Escape, or vanishes when the pointer moves onto it → keep it hoverable and dismissible (1.4.13, AA).

## Operable

- `onClick` on `<div>`/`<span>` → use `<button>`; if impossible, add `role="button"`, `tabIndex={0}`, and Enter and Space key handlers (2.1.1, A; 4.1.2, A).
- `<a>` without `href` used as a button, or `href="#"` with `onClick` → use `<button>` (2.1.1, A; 4.1.2, A).
- Mouse-only handlers (`onMouseDown`, `onMouseOver`, drag) with no keyboard equivalent → add keyboard handlers (2.1.1, A).
- Focus can enter a widget but not leave (no Escape, Tab blocked) outside a modal → release focus (2.1.2, A).
- Single-character key shortcut with no way to turn off or remap → require a modifier, or allow disable (2.1.4, A).
- Timeout or session expiry with no warning and no way to extend → warn and allow extend or turn off (2.2.1, A).
- Auto-advancing carousel, marquee, or animation >5s with no pause control → add pause/stop (2.2.2, A).
- Flashing content more than three times per second → remove or slow it (2.3.1, A).
- Page with repeated navigation and no skip link or landmarks → add "Skip to main content" targeting `<main>` (2.4.1, A).
- Missing or generic `<title>` / route title not updated in an SPA → set a descriptive title (2.4.2, A).
- Positive `tabIndex` (`tabIndex={1}`) → remove; fix DOM order (2.4.3, A).
- Dialog open does not move focus inside, or close does not restore focus to the trigger → move and restore focus (2.4.3, A).
- Link text "click here" / "read more" with no context → make the text name the target, or add `aria-label` (2.4.4, A).
- `outline: none` / `outline: 0` on `:focus` with no replacement style → add a visible `:focus-visible` style (2.4.7, AA).
- `<label>` text not contained in the control's accessible name (`aria-label` differs from visible text) → start the name with the visible text (2.5.3, A).
- Action that fires on pointer down with no way to abort → fire on up/click (2.5.2, A).
- Path or multi-point gesture (swipe, pinch) with no single-pointer alternative → add buttons (2.5.1, A).
- Feature triggered only by device motion → add a UI control and allow disable (2.5.4, A).

## Understandable

- `<html>` without `lang`, or an invalid code → add `lang="en"` (or the page language) (3.1.1, A).
- Passage in another language without `lang` on its element → add `lang` (3.1.2, AA).
- `onFocus` or `onChange` that submits, navigates, or opens a new window → trigger on an explicit action (3.2.1, A; 3.2.2, A).
- Navigation order or labels that differ across pages → keep them consistent (3.2.3, AA; 3.2.4, AA).
- Error shown only by red border, or not associated with the field → add error text linked by `aria-describedby`; set `aria-invalid="true"` (3.3.1, A).
- `<input>`, `<select>`, `<textarea>` without `<label for>`, wrapping `<label>`, `aria-label`, or `aria-labelledby` → add a label (3.3.2, A; 1.3.1, A; 4.1.2, A).
- `placeholder` as the only label → add a persistent label (3.3.2, A).
- Required field marked only with `*` or color → add `required` / `aria-required="true"` and text (3.3.2, A).
- Error message with no suggested fix when one is known ("invalid date" vs "use YYYY-MM-DD") → suggest the fix (3.3.3, AA).
- Legal, financial, or data-deleting submit with no review, confirm, or undo → add one (3.3.4, AA).

## Robust

- Duplicate `id` within a page or rendered list (hard-coded `id` in a repeated component) → make it unique (`useId()` or a prefix) (4.1.1, A).
- `aria-labelledby` / `aria-describedby` / `for` pointing at a missing `id` → fix the reference (4.1.1, A; 4.1.2, A).
- Interactive element nested in another (`<button>` in `<a>`, `<a>` in `<button>`, input in a clickable row) → un-nest; one control per target (4.1.2, A).
- Custom control missing role, name, or state (`aria-expanded`, `aria-checked`, `aria-selected`, `aria-pressed`) → add per pattern below (4.1.2, A).
- `role` that overrides a native element's semantics (`<button role="link">`, `<h2 role="button">`) → use the right element (4.1.2, A).
- `aria-hidden="true"` on a focusable element or its ancestor → remove, or make it inert/unfocusable (4.1.2, A).
- Invalid ARIA attribute or value for the role (`aria-checked` on a `button`) → use the attribute the role supports (4.1.2, A).
- Toast, "saved", result count, or async error rendered without a live region → wrap in `role="status"` (polite) or `role="alert"` (urgent); the container must exist before content changes (4.1.3, AA).
- Live region added to the DOM at the same time as its message → render the empty region first (4.1.3, AA).

## Widget patterns

Required semantics per WAI-ARIA APG. Check the component library first; flag only what the caller still owes.

- **Dialog (modal):** `role="dialog"` (or `alertdialog`), `aria-modal="true"`, accessible name via `aria-labelledby` or `aria-label`; focus moves in on open, Tab cycles inside, Escape closes, focus returns to the trigger. Native `<dialog>` with `showModal()` supplies role, modality, and Escape.
- **Disclosure / accordion:** trigger is a `<button>` with `aria-expanded` and `aria-controls`.
- **Menu button:** `<button aria-haspopup="menu" aria-expanded>`; menu `role="menu"`, items `role="menuitem"`; arrow keys move, Escape closes and restores focus. Site navigation is a list of links, not `role="menu"`.
- **Tabs:** `role="tablist"`, `role="tab"` with `aria-selected` and `aria-controls`, `role="tabpanel"` with `aria-labelledby`; arrow keys move between tabs, one tab in the Tab order.
- **Combobox:** `role="combobox"`, `aria-expanded`, `aria-controls` the `listbox`, `aria-activedescendant` for the highlighted option.
- **Checkbox / switch:** prefer `<input type="checkbox">`; custom needs `role="checkbox"` or `role="switch"`, `aria-checked`, Space toggles.
- **Tooltip:** `role="tooltip"`, referenced by `aria-describedby`; shows on focus as well as hover, Escape dismisses.

## Sources

- [WCAG 2.1](https://www.w3.org/TR/WCAG21/), W3C Recommendation. W3C Document License.
- [WAI-ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/), W3C. W3C Document License.
- [Using ARIA](https://www.w3.org/TR/using-aria/), W3C. W3C Document License.
