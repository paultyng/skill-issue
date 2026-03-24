---
paths:
  - "**/*_test.go"
  - "e2e/**/*.go"
---

# testing-philosophy

Testing preferences:

- Always prefer real code, a local version of a server (like `httptest`), or dependency injection over static mocks. Mocks are a last resort.
- Tests must be self-contained. The only shared infrastructure allowed is the database.
- **Database**: tests may depend on a real database connection — this is expected and acceptable.
- **External services** (gRPC clients, HTTP APIs, third-party SDKs): must be mocked or stubbed. Tests must never make real calls to external services.
- Use interfaces for service dependencies so they are straightforward to mock in tests. Keep mocks minimal — only stub the methods the test actually exercises.
- For time-dependent tests, prefer `testing/synctest` over real sleeps/timers (Go 1.25+).
- Use `t.Parallel()` for independent tests.
