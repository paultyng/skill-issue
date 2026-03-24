---
name: create-decision-document
description: Create or update a Notion decision document with a structured options/pros/cons/recommendation template. Use when the user asks to create a decision doc, design doc, evaluation doc, or comparison in Notion.
---

# Create Decision Document

Create or update a decision document in Notion using the Notion MCP.

## 1. Gather Context

Determine from the user:
- **Title**: what decision is being made
- **Location**: which Notion page or database to create under (ask if unclear)
- **Options**: the alternatives being evaluated (may emerge during research)

## 2. Research (if needed)

If the user asks for research before writing:
- Use **Sourcegraph** for organization's codebase patterns and precedent
- Use **web search** for external APIs, standards, and vendor comparisons
- Use **Notion** for existing internal docs and prior decisions
- Be terse in research summaries

## 3. Create the Document

Use the Notion MCP to create a page with this structure:

```markdown
# <Decision Title>

## Problem Statement
<1-2 sentences describing what needs to be decided and why>

## Options

### Option A: <Name>
**Pros**
- <terse bullet>
- <terse bullet>

**Cons**
- <terse bullet>
- <terse bullet>

### Option B: <Name>
**Pros**
- <terse bullet>

**Cons**
- <terse bullet>

## Recommendation
<Which option and why, 1-2 sentences>
```

Formatting rules:
- Be terse throughout. No filler.
- Do **not** prefix Pros/Cons items with "Good:" or "Bad:".
- Bullet points, not prose paragraphs.
- If there are criteria or requirements, use a comparison table rather than repeating them per option.

## 4. Follow-up

Common follow-up actions (do only if asked):
- Link a PR to the decision doc
- Update the recommendation after discussion
- Add a "Decision" or "Status" field marking the choice as final
