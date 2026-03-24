# Protobuf and API Design — Reference

Reference sources:
- [Protobuf Best Practices](https://protobuf.dev/best-practices/dos-donts/)
- [AEP (API Enhancement Proposals)](https://aep.dev/)
- [AEP Numbered List](https://aep.dev/aep_list/)

## Automated Linting

The following tools are run opportunistically if available on PATH:

- **[buf lint](https://buf.build/docs/reference/cli/buf/lint/)**: 100+ built-in protobuf lint rules covering naming, package structure, and best practices. Configured via `buf.yaml`.
- **[buf breaking](https://buf.build/docs/breaking/)**: Detects backwards-incompatible schema changes by comparing against a reference (e.g. `buf breaking --against .git#branch=main`). Categories: `WIRE`, `WIRE_JSON`, `PACKAGE`, `FILE` (default).

## Message Design

- One top-level message or service per file (proto style)
- Separate RPC request/response messages from storage/domain messages
- Reserve deleted field tags and names — never reuse a tag number
- Use well-known types (`google.protobuf.Timestamp`, `google.protobuf.Duration`, `google.protobuf.FieldMask`, etc.) instead of reinventing
- Don't change the type of an existing field
- Don't add required fields to existing messages (proto3 doesn't have `required`, but don't simulate it)

## Field Conventions

- Use `snake_case` for field names
- Use singular for scalar fields, plural for repeated fields
- Enum first value should be `_UNSPECIFIED = 0` (AEP-126)
- Boolean fields: use positive naming (`enable_x` not `disable_x`), avoid double negatives
- String fields for identifiers: document format constraints

## Resource Design (AEP)

- Resources have a `name` field with a resource name pattern (AEP-122, AEP-123)
- Standard methods: Get, List, Create, Update, Delete (AEP-131 through AEP-135)
- Use `google.protobuf.FieldMask` for partial updates (AEP-134)
- `page_size` / `page_token` for list pagination (AEP-132)
- Singleton resources when appropriate (AEP-156)

## Service and RPC Design

- One service per proto file
- RPC should describe the action, not the implementation
- Use standard method signatures per AEP conventions
- Request messages named `<Method>Request`, response messages named `<Method>Response`
- Long-running operations for async work (AEP-151)

## Field Behavior and Annotations

- Mark fields with appropriate behavior: `INPUT_ONLY`, `OUTPUT_ONLY`, `IMMUTABLE`, `REQUIRED` (AEP-203)
- AEP-203 applies to request messages only, not response messages
- Use `google.api.resource` and `google.api.resource_reference` annotations for resource relationships

## Compatibility

- Never remove or reuse a field tag number — reserve them
- Adding fields to existing messages is safe
- Removing fields: reserve the tag number and field name
- Enum values: reserve removed values
- Don't rename fields (wire format uses tag numbers, but JSON uses names)

---

## Cross-references

- For documentation quality (doc comments, examples, README sync): see **review-documentation**
- For DoS-related security concerns (rate limiting, resource limits): see **review-security**
- For operational stability (graceful shutdown, circuit breakers, timeouts): see **review-reliability**
