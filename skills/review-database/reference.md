# Database & SQL — Framework Reference

Detailed checklists for database review. The SKILL.md workflow references this file.

Reference sources:
- [strong_migrations](https://github.com/ankane/strong_migrations) — codified list of unsafe PostgreSQL migration operations
- [Use The Index, Luke](https://use-the-index-luke.com/) — Markus Winand (SQL indexing and query performance)
- [PostgreSQL Lock Management](https://www.postgresql.org/docs/current/explicit-locking.html) — lock levels and DDL interactions
- [MySQL Online DDL Operations](https://dev.mysql.com/doc/refman/en/innodb-online-ddl-operations.html) — algorithm and lock behavior per operation
- [MySQL Online DDL Limitations](https://dev.mysql.com/doc/refman/en/innodb-online-ddl-limitations.html) — metadata lock and failure conditions

Detect which database engine is in use (check Go imports for `pgx`/`pq`/`lib/pq` for PostgreSQL, `go-sql-driver/mysql` for MySQL, migration tool configs, connection strings) and apply the appropriate engine-specific checklist below.

## Migration Safety (PostgreSQL)

**Automated linting:** [squawk](https://squawkhq.com/) is run opportunistically for PostgreSQL projects. Run via `npx squawk-cli <migration_files>` or `squawk` if on PATH. Squawk implements the strong_migrations rules below as automated checks.

Based on strong_migrations rules. These DDL operations are unsafe in production because they acquire `ACCESS EXCLUSIVE` locks (blocking all reads and writes) or can cause application errors during rollout:

**Column operations:**
- Adding a column with a volatile default — rewrites the entire table under lock; instead add nullable column, then backfill, then set default
- Setting `NOT NULL` on an existing column — acquires `ACCESS EXCLUSIVE` and scans the entire table; instead add a `CHECK` constraint with `NOT VALID`, then validate separately
- Changing a column's type — rewrites the table; instead add a new column, backfill, swap in application code, drop old column
- Removing a column — application may still reference it during rollout; instead stop reading/writing the column first, then remove in a subsequent migration
- Renaming a column or table — breaks application code that references the old name during rollout

**Index operations:**
- Creating an index without `CONCURRENTLY` — blocks writes for the duration of the build
- Dropping an index without `CONCURRENTLY` — blocks writes briefly but can still cause issues under load

**Constraint operations:**
- Adding a foreign key — validates existing rows under `ACCESS EXCLUSIVE`; instead add with `NOT VALID`, then validate separately
- Adding a unique constraint — implicitly creates an index non-concurrently; instead create the index concurrently, then add the constraint using the index
- Adding a check constraint — scans the table under lock; instead add with `NOT VALID`, then validate separately
- Adding an exclusion constraint — no concurrent alternative; requires careful scheduling

**General migration practices:**
- Backfilling data in the same migration as the schema change — should be a separate step
- Migrations should be reversible or have a documented rollback plan
- Reserved tags/names should be recorded when removing columns (relevant to proto/schema alignment)

## Query Performance

Based on Use The Index, Luke and common PostgreSQL anti-patterns:

**Index coverage:**
- Foreign key columns have indexes (PostgreSQL does not auto-create them)
- Columns used in `WHERE`, `JOIN`, and `ORDER BY` clauses on hot-path queries are indexed
- Composite indexes match the query's column order (leftmost-prefix rule)
- Partial indexes are used where applicable (e.g. `WHERE deleted_at IS NULL`)
- Indexes that are not referenced by any query in the codebase may be unnecessary (write overhead without read benefit)

**Query patterns:**
- N+1 queries: loops that issue one query per row instead of batching
- `SELECT *` in application code: fetches unnecessary columns, defeats covering indexes
- Unbounded queries: `SELECT` without `LIMIT` or pagination on user-facing paths
- Serial queries that could be parallelized or batched (multiple independent round-trips per request)
- Functions in `WHERE` clauses that prevent index usage (e.g. `WHERE LOWER(email) = ...` without a functional index)
- Implicit type casts in comparisons that prevent index usage

## Connection & Transaction Management

**Connection pool configuration:**
- Max open connections is set explicitly (Go's default is unlimited)
- Max idle connections and idle timeout are configured
- Connection lifetime (`SetConnMaxLifetime`) is set to prevent stale connections after failover or DNS changes

**Transaction scope:**
- Transactions are as short as possible — no external calls (HTTP, gRPC, message publish) inside a transaction
- `defer tx.Rollback()` is called immediately after `Begin` to ensure cleanup on error paths
- Read-only queries use read-only transactions or no transaction where possible
- Serialization failures (`40001`) are retried, not propagated as errors

**Context propagation:**
- All database calls receive the request context (`ctx`) so they are cancelled when the client disconnects or deadline expires
- Long-running queries (reports, migrations) use a separate context, not the request context
- Statement timeouts are set as a safety net (`SET statement_timeout` or connection-level default)

## Schema Design (PostgreSQL)

**Data types:**
- Use `BIGINT` or `UUIDv7` for primary keys, not `UUIDv4` (random UUIDs scatter B-tree inserts)
- Use `timestamptz` (not `timestamp`) for all time values
- Use `text` rather than `varchar(n)` unless a hard length constraint is required (PostgreSQL treats them identically in performance; `varchar(n)` adds a check on every write)
- Use `jsonb` (not `json`) when storing JSON — `jsonb` supports indexing and efficient operators

**Constraints:**
- Primary keys and unique constraints exist for all identity columns
- Foreign key constraints enforce referential integrity (with appropriate `ON DELETE` behavior)
- `NOT NULL` constraints on columns that should never be null
- Check constraints for domain validation (e.g. positive amounts, valid enum values)

## Migration Safety (MySQL)

MySQL DDL safety depends on the algorithm chosen (INSTANT, INPLACE, or COPY), which varies by operation and MySQL version. Unlike PostgreSQL, there is no `CREATE INDEX CONCURRENTLY` equivalent; instead, MySQL's Online DDL provides in-place operations that allow concurrent DML in most cases.

**ALTER TABLE algorithm awareness:**
- **INSTANT** (MySQL 8.0.12+): metadata-only change, no table rebuild. Available for appending columns (at table end), adding/dropping virtual columns, and some default changes. Not available for inserting columns in the middle, dropping columns (before 8.0.29), or reordering.
- **INPLACE**: modifies the table in place without a full copy. Allows concurrent DML in most cases but still acquires brief exclusive metadata locks at start and end of the operation.
- **COPY**: full table rebuild — creates shadow table, copies all rows, acquires exclusive lock, drops original, renames. Blocks writes for the entire duration, scales with row count. Operations requiring COPY include changing a column type, dropping a primary key, and converting character set.

**Metadata lock blocking:**
- Long-running transactions holding metadata locks on a table cause DDL to queue waiting for the lock. While the DDL is queued, all subsequent queries on the same table also block behind it, creating a cascading stall.
- Ensure no long-running queries or open transactions exist on target tables before running DDL.

**Online DDL log overflow:**
- During INPLACE ALTER TABLE, concurrent DML is recorded in an online log. If the log exceeds `innodb_online_alter_log_max_size` (default 128MB), the ALTER fails.
- High-write tables with long-running ALTERs are at risk; consider external tools for these cases.

**Foreign key constraints:**
- `LOCK=NONE` (fully concurrent DDL) is not permitted on tables with `ON CASCADE` or `ON SET NULL` foreign key constraints.

**Large table migrations:**
- For tables too large for online DDL (COPY algorithm, high write volume, or replication lag concerns), flag that external tools like [gh-ost](https://github.com/github/gh-ost) or [pt-online-schema-change](https://docs.percona.com/percona-toolkit/pt-online-schema-change.html) should be considered.
- gh-ost: triggerless, binlog-based, lower master load, but does not support foreign keys or tables with existing triggers.
- pt-online-schema-change: trigger-based, supports foreign keys, works on MySQL 5.5+.

**General migration practices (MySQL):**
- Removing/renaming columns: same rollout risk as PostgreSQL — stop reading/writing the column first, then remove in a subsequent migration.
- Backfilling data in the same migration as the schema change — should be a separate step.
- Migrations should be reversible or have a documented rollback plan.

## Schema Design (MySQL)

**Data types:**
- Use `BIGINT` or `UUIDv7` for primary keys, not `UUIDv4` (random UUIDs scatter B-tree inserts, same as PostgreSQL)
- Use `InnoDB` engine (not `MyISAM`) — InnoDB supports transactions, row-level locking, and foreign keys
- Use `utf8mb4` charset (not `utf8` which is MySQL's 3-byte alias and cannot represent all Unicode characters)
- Use `DATETIME` with timezone handling at the application layer, or `TIMESTAMP` (auto-converts to UTC but limited to year 2038)
- Avoid `ENUM` for values that change frequently — adding new enum values requires an ALTER TABLE DDL operation
- Use `JSON` column type (MySQL 5.7+) with generated columns for indexing specific paths, rather than indexing the entire JSON blob

**Constraints:**
- Primary keys and unique constraints exist for all identity columns
- Foreign key constraints enforce referential integrity (with appropriate `ON DELETE` behavior)
- `NOT NULL` constraints on columns that should never be null
- Check constraints for domain validation (MySQL 8.0.16+ enforces `CHECK` constraints; earlier versions parse but ignore them)
