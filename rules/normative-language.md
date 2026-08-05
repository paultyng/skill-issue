# normative-language

Requirement levels in rules, skills, and plans use the RFC 2119 / RFC 8174 (BCP 14) key words, so a reader can tell a hard requirement from a strong default from an option.

- **MUST** / **MUST NOT** (= REQUIRED, SHALL / SHALL NOT): an absolute requirement. No agent discretion.
- **SHOULD** / **SHOULD NOT** (= RECOMMENDED): a strong default. Deviate only with a stated reason.
- **MAY** (= OPTIONAL): genuinely discretionary.

How to use them:

- **Only UPPERCASE carries this meaning** (RFC 8174). Lowercase "should", "may", "might", "could" are ordinary hedges — keep deleting them per `terse-output` and `simplify-prose`. The uppercase form is the signal that you meant it precisely.
- **Use them sparingly** (RFC 2119 §6). Reserve them for genuine requirement levels; do not decorate ordinary prose. Most sentences need no keyword.
- **`MUST` carries requirement emphasis.** It replaces the older "YOU MUST" wording. When a requirement is also frequently violated, a short lead-in ("Frequently missed:") plus `MUST` beats stacking emphasis.

Reference: RFC 2119 and RFC 8174 (BCP 14).
