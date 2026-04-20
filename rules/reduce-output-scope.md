# reduce-output-scope

When producing output (plans, docs, recommendations, options), include only what was asked for.

- Do not enumerate alternatives, tiers, or edge cases unless requested.
- Start minimal — the user will ask for more detail if needed.
- When writing decision docs or design docs, cover the requested scope only. Do not add sections for "future considerations" or options the user didn't mention.
- If the user says "drop X", that signals over-scoping. Recalibrate for the rest of the session.
- This complements `minimal-changes` (which covers code). This rule covers prose, plans, and recommendations.
