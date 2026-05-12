# no-generated-file-edits

Never lint, format, or modify files that are code-generated.

- Generated files include output from buf, protoc, sqlc, openapi-generator, and similar tools.
- If a generated file has issues, fix the generator input or config, not the output.
- When unsure if a file is generated, check for generation headers/comments (e.g. `// Code generated ... DO NOT EDIT.`) before editing.
