# Horizontal Sharding — Framework Reference

Checklist for reviewing horizontally sharded databases. The SKILL.md workflow references this file when sharding is detected.

Reference sources:
- [Vitess Sharding Guidelines](https://vitess.io/docs/22.0/user-guides/vschema-guide/sharding-guidelines) — sharding key selection, co-location, cross-shard transactions
- [Vitess Query Plans Classification](https://vitess.io/docs/22.0/reference/query-serving/metrics) — query plan types and scatter detection
- [PlanetScale: Avoiding Cross-Shard Queries](https://planetscale.com/docs/vitess/sharding/avoiding-cross-shard-queries) — practical Vitess sharding patterns
- [Citus: Choosing Distribution Column](https://learn.microsoft.com/en-us/postgresql/citus/data-modeling?view=citus-14) — PostgreSQL sharding key selection and co-location
- *Designing Data-Intensive Applications* (Kleppmann), Chapter 6 — partitioning strategies, hot spots, skewed workloads

Apply this checklist when the project uses a sharded database (Vitess, PlanetScale, Citus, Spanner, CockroachDB, or any custom sharding layer). Skip if the database is unsharded.

## Detecting Sharding

- VSchema files (`vschema.json`, `*.vschema`), Vitess gateway imports, or PlanetScale configuration
- Citus `create_distributed_table` calls or `citus.shard_count` settings
- Spanner `INTERLEAVE IN PARENT` clauses
- Multi-column primary keys where the leading column is a tenant/partition ID
- Application-level shard routing or middleware (e.g. shard-aware connection pools, custom router)

## Sharding Key in Hot-Path Queries

- Every data-plane / high-QPS query (`SELECT`, `UPDATE`, `DELETE`) MUST include the sharding key in its `WHERE` clause so the router targets a single shard (or minimal shard subset)
- Queries that omit the sharding key become scatter queries — broadcast to every shard, with cost scaling linearly with shard count
- Flag any hot-path query that does not filter on the sharding key

## Co-location for Joins and Transactions

- Tables frequently JOINed together should share the same sharding key (primary vindex / distribution column) so related rows reside on the same shard
- Transactions should stay within a single shard; cross-shard transactions require 2PC (Vitess) or similar coordination, adding latency and failure modes
- Flag cross-shard JOINs and multi-shard transactions on hot paths

## Scatter Query Anti-Patterns

- `SELECT` / `UPDATE` / `DELETE` without sharding key in `WHERE` (full scatter)
- Aggregations across all shards (`COUNT(*)`, `SUM()`, `ORDER BY`) without a shard-scoped filter — each shard computes partial results and the coordinator must merge
- Pagination (`LIMIT` / `OFFSET`) without sharding key — every shard processes the full offset, then results are merged and re-sorted
- N+1 loops where the inner query scatters (multiplied cost: N scatter queries)
- Cross-shard JOINs on hot paths — the gateway must fetch from multiple shards and join in memory

## Sharding Key Selection (Schema Review)

- **Uniqueness**: the key must map each value to exactly one shard (deterministic routing)
- **High cardinality**: sufficient distinct values to distribute evenly across shards; avoid low-cardinality keys (status, region code, boolean) that create hot shards
- **Frequency in queries**: the highest-QPS query's primary filter should dictate the sharding key
- **Uniform distribution**: avoid keys that skew (e.g. timestamps with hash-based sharding concentrate recent writes; sequential IDs create append-only hot spots)
- **Co-location alignment**: if multiple tables are sharded, they should share a key that groups related rows together (e.g. `tenant_id` across all tenant-scoped tables)

## Vitess / PlanetScale

- Query plan preference: `Passthrough` > `Lookup` > `MultiShard` > `Scatter`; flag `Scatter` and `JoinOp` plans on hot paths
- Vindex hints (`USE VINDEX`, `IGNORE VINDEX`) can steer the query planner when the default routing is suboptimal
- Subsharding vindexes (multicol) for large-tenant or geo-sharding scenarios where a single tenant spans multiple shards
- `AUTO_INCREMENT` must be removed from sharded tables — each shard is a separate MySQL instance and cannot coordinate uniqueness; use Vitess sequences instead
- Many-to-many relationships: pick the strongest relationship for co-location; consider materialized views (Vitess `Materialize`) for the secondary relationship

## Citus (PostgreSQL)

- Use `create_distributed_table('table', 'distribution_column')` with the tenant/partition column
- Small cross-tenant lookup tables should be reference tables (`create_reference_table`) to avoid replication overhead
- Queries should include the distribution column in `WHERE` so Citus routes to a single worker node

## Spanner

- Use `INTERLEAVE IN PARENT` to physically co-locate parent-child rows on the same split
- Avoid monotonically increasing primary keys (timestamps, sequential IDs) — they create write hot spots on the last split; use UUIDv4 or bit-reversed sequences
