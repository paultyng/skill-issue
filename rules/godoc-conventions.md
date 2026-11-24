---
paths:
  - "**/*.go"
---

# godoc-conventions

Go doc comments are not Markdown. Write them in the syntax `go doc` and pkg.go.dev render. When to write a comment at all is `terse-comments`.

## Renders

- **Heading:** `# Heading` on its own line, with a blank `//` line before and after. One `#` only.
- **Symbol link:** `[Symbol]` or `[pkg.Symbol]` links to a Go identifier in scope. Link to it instead of re-explaining it.
- **URL link:** `[Text]` in the prose plus a definition line `[Text]: https://...` at the end of the comment. A bare URL also links.
- **List:** indent the marker (`//   - item`, `//  1. item`). An unindented `- item` merges into the paragraph text.
- **Preformatted block:** indent every line with a tab or extra spaces. Use this for tables, code, and ASCII diagrams.
- **Paragraph break:** a blank `//` line. Adjacent lines join into one paragraph.

## Renders literally

- Inline Markdown links `[text](https://...)`
- `**bold**`, `_italic_`, and backtick code spans. Write the identifier plainly or as `[Symbol]`.
- Unindented pipe tables. Their rows join into one line.
- HTML

## Conventions

- Start the comment with the name of the symbol it documents: `// Foo returns ...`.
- Cite specs by name (`RFC 7519`). Add a section number only when the reader needs it.
- After a doc comment edit that adds a heading, list, link, or table, run `go doc <pkg>` (or `go doc -all <pkg>`) and read the output. `gofmt` fixes spacing around lists but does not flag literal Markdown.

Reference: [Go Doc Comments](https://go.dev/doc/comment).
