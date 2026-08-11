# no-post-without-confirmation

**NEVER** post comments, reviews, messages, or any externally visible content (GitHub PR comments, Slack messages, Jira updates, Notion pages, etc.) without first showing the draft to the user and receiving explicit confirmation to post.

- Always present the full text of what will be posted and ask for approval.
- "Write up a comment" means draft it for the user to review, not post it.
- This applies even when the user's phrasing could be interpreted as an instruction to post directly.
- When in doubt, show the draft and ask.

Scope: this rule governs whether externally-visible **content** may be published, so it needs draft approval. It does not govern *timing*. When the operation is also timing- or sequencing-sensitive (a merge, deploy, or gated CI run), `defer-external-orchestration` also applies: approval authorizes the text, not the moment of firing. Get the content approved, then let the user trigger the send.
