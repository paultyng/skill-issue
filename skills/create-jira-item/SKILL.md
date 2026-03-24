---
name: create-jira-item
description: Create Jira issues (stories, epics, initiatives) with custom field introspection to fill org-specific fields correctly. Use when the user asks to create a Jira ticket, story, epic, initiative, or task.
---

# Create Jira Item

Create Jira issues using the Atlassian MCP, with proper custom field handling.

## 1. Determine Target

- **Project**: Use the project specified by the user. If not specified, infer by searching the user's recent issues (`searchJiraIssuesUsingJql` with `(assignee = currentUser() OR reporter = currentUser()) ORDER BY updated DESC`). If inference fails, ask.
- **Issue type**: story, epic, task, initiative, etc. Infer from context or ask.

## 2. Introspect Custom Fields

Before creating the issue, discover the project's field requirements:

1. Get available issue types via `getJiraProjectIssueTypesMetadata(cloudId, projectIdOrKey)`.
2. Get field metadata for the chosen issue type via `getJiraIssueTypeMetaWithFields(cloudId, projectIdOrKey, issueTypeId)`.

3. Pay attention to:
   - **Required fields** that are not standard (e.g., "Team", "Quarter", "Initiative Link", "Sprint")
   - **Custom field IDs** (`customfield_NNNNN`) -- use these in the create call
   - **Allowed values** for select/multi-select fields

For **epics and initiatives** especially, org-specific fields are common and must be populated. Do not rely on default field assumptions.

## 3. Create the Issue

Use `createJiraIssue` with:
- **Summary**: terse, descriptive title
- **Description**: terse. Bullet points preferred. No boilerplate.
- **Assignee**: current user (use `lookupJiraAccountId` if needed)
- **Priority**: Medium unless user specifies otherwise
- All required custom fields populated from step 2

## 4. Link to Epic (if applicable)

If the issue should be under an epic:
- Use `createIssueLink` or set the epic link field (varies by Jira config)
- If the user mentions an epic by name or key, search for it first via `searchJiraIssuesUsingJql(cloudId, "project = X AND issuetype = Epic AND summary ~ 'name'")`.

## 5. Report

Return the issue key and URL. If any required fields were unknown or couldn't be populated, note them.
