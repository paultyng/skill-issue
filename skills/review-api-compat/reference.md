# API Compatibility Review: Framework Reference

Detailed checklists for breaking-change classification. SKILL.md references this file.

Reference sources:
- [buf: Breaking change detection](https://buf.build/docs/breaking/overview)
- [Protocol Buffers: Updating a message type](https://protobuf.dev/programming-guides/proto3/#updating)
- [Google AIP-180: Backwards compatibility](https://google.aip.dev/180)
- [OpenAPI Spec 3.1: Versioning](https://swagger.io/blog/news/whats-new-in-openapi-3-1/)
- [oasdiff: Breaking change classification](https://github.com/oasdiff/oasdiff)

## Table of contents

- [Change classes](#change-classes)
- [Protobuf change matrix](#protobuf-change-matrix)
- [OpenAPI change matrix](#openapi-change-matrix)
- [GraphQL change matrix](#graphql-change-matrix)
- [Remediation patterns](#remediation-patterns)

## Change classes

- **wire-breaking**: changes the on-the-wire encoding such that an existing client receiving the new server response (or sending to a new server) deserializes incorrectly or fails. Examples: changing a proto field number, changing a JSON field type from `string` to `integer`.
- **behavior-breaking**: wire format is unchanged but the semantics change. Examples: an OpenAPI response field changes meaning, a proto enum value's intent changes, a previously-optional behavior becomes mandatory. Caught by humans, not tools.
- **policy-breaking**: violates a declared compatibility policy (e.g. buf `WIRE_JSON` policy when only `WIRE` would have passed). The wire change might be safe in some channels but not the one the project promises to support.
- **non-breaking**: additive in both wire and semantic terms. Safe to merge.

## Protobuf change matrix

Per [protobuf docs](https://protobuf.dev/programming-guides/proto3/#updating) and [buf breaking rules](https://buf.build/docs/breaking/rules):

| Change | Wire | JSON | Notes |
|---|---|---|---|
| Add a new field with a new field number | non-breaking | non-breaking | Default for evolution |
| Remove a field | wire-breaking | wire-breaking | Reserve the field number and name first; only safe to remove after a deprecation cycle |
| Rename a field | non-breaking (wire) | wire-breaking (JSON) | JSON serialization uses the field name; wire uses the number |
| Change a field number | wire-breaking | non-breaking | Never reuse a field number |
| Change a field type | usually wire-breaking | depends | Some int32↔uint32↔bool combinations are wire-compatible but semantically dangerous; treat as breaking |
| Make a field `repeated` (or vice versa) | wire-breaking | wire-breaking | |
| Add a value to an enum | non-breaking | non-breaking | Clients must handle unknown values; document the default |
| Remove an enum value | behavior-breaking | behavior-breaking | Existing data with that value becomes unrepresentable |
| Reserve a previously-used field number or name | non-breaking | non-breaking | Required step before reuse safety |
| Move a field into / out of a `oneof` | wire-breaking | wire-breaking | Singular fields and oneof members differ in presence semantics |
| Add a method to a service | non-breaking | n/a | Clients without the method just don't call it |
| Remove a method from a service | wire-breaking | n/a | Existing clients calling the method now error |
| Rename a method | wire-breaking | n/a | RPC dispatch is by name |
| Change request or response type of an RPC | wire-breaking | n/a | |
| Add a new service | non-breaking | n/a | |
| Move a message to a different package | wire-breaking | wire-breaking | The fully-qualified name changes |
| Change `optional` to required (proto2) | behavior-breaking | behavior-breaking | proto3 has no `required`; `optional` only changes presence semantics |

**Buf rule sets** (most strict to least):
- `WIRE_JSON`: blocks all wire and JSON breaks. Use when both proto and JSON clients consume the API.
- `WIRE`: blocks wire breaks only; field renames are allowed. Use when only generated gRPC clients consume.
- `PACKAGE`: looser, package-level checks; usually not appropriate for production services.
- `FILE`: even looser; for internal-only protos.

Default to `WIRE_JSON` for any externally-consumed API.

## OpenAPI change matrix

Per [oasdiff](https://github.com/oasdiff/oasdiff/blob/main/BREAKING-CHANGES-EXAMPLES.md) and standard REST evolution rules:

**Wire/JSON breaking:**
- Removing an endpoint (method + path)
- Removing a response property that was guaranteed (`required` or always present)
- Changing the type of a request or response property
- Tightening a property: optional → required (request); always-present → optional (response)
- Adding a new required request property without a default
- Removing or renaming a query/path/header parameter
- Tightening parameter constraints (smaller `maxLength`, narrower `enum`, stricter `pattern`)

**Behavior breaking (tools may not catch):**
- Changing the semantics of an existing field while keeping the type
- Changing the error response shape or status code mapping
- Changing rate limits, authentication requirements, or pagination behavior
- Changing the default for an optional parameter

**Non-breaking:**
- Adding a new endpoint
- Adding a new optional request property
- Adding a new response property (clients should ignore unknown fields per Postel's Law, but explicitly test this assumption)
- Loosening a property: required → optional (request); optional → always-present (response)
- Widening parameter constraints

**Caveats:**
- Tools sometimes miss media-type changes (`application/json` vs. `application/vnd.api+json`); double-check `requestBody.content` keys.
- `additionalProperties: false` flipping to `true` (or absent) is technically loosening but can break strict clients.
- `nullable: true` on a previously-non-nullable field is breaking for clients that don't handle null.

## GraphQL change matrix

**Breaking:**
- Removing a type, field, argument, enum value, or directive
- Renaming any of the above
- Changing a field's type (covariance: a field returning `User!` cannot become `User`; arguments are contravariant — `String!` arg cannot become `String!`-required-or-other)
- Making an optional argument required
- Changing an enum value's meaning

**Non-breaking:**
- Adding a new type, field, argument (with default), or enum value
- Adding a deprecation reason
- Making a required argument optional (with a sensible default)

## Remediation patterns

**Deprecate-then-remove cycle:**
1. Add the new field/method/endpoint as the replacement.
2. Mark the old one deprecated: proto `deprecated = true` option / OpenAPI `deprecated: true` / GraphQL `@deprecated(reason: "...")`.
3. Update docs and changelog directing consumers to the replacement.
4. After a documented soak period (e.g. 2 releases or 90 days), remove the old surface in a major version bump.

**Version bump:**
- Proto: introduce a new package `pkg.v2` alongside `pkg.v1`. Keep `v1` until consumers migrate.
- OpenAPI: introduce a new path prefix (`/v2/`) or `Accept` media type version (`application/vnd.api+json; version=2`).
- Major-version bumps are blast-radius events; coordinate with consumers before merging.

**Additive alternative:**
- New field instead of changing an existing one. Most breaks are avoidable this way.
- For enum value changes, add a new value and deprecate the old; do not reuse the old.

**Reservation hygiene (proto):**
- When removing a field, `reserved <number>; reserved "<name>";` in the same change so the number/name can't be accidentally reused.
- buf's `WIRE` rule enforces this when configured; verify it's on.

**Consumer-search:**
- Before any break (even policy-permitted), search the org codebase for consumers of the changed surface. A field nobody reads is cheap to remove; a field 200 services read is not.
