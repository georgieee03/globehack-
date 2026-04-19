/**
 * Unit tests for Recovery Graph data layer
 *
 * Tests use a lightweight Supabase client stub to verify that the correct
 * queries and inserts are issued without requiring a live database.
 *
 * Requirements: 7.1, 7.2, 7.3, 7.4, 8.5
 */

import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  insertRecoveryGraphPoints,
  insertCheckinGraphPoints,
  queryRecoveryGraph,
  recomputeAndInsertRecoveryScore,
} from "./recovery-graph.ts";
import type { BodyRegion } from "../_shared/safe-envelope.ts";

// ---------------------------------------------------------------------------
// Supabase client stub
// ---------------------------------------------------------------------------

interface InsertedRow {
  table: string;
  rows: unknown;
}

interface QueryCall {
  table: string;
  filters: Record<string, unknown>;
  selectFields?: string;
  orderField?: string;
  orderAscending?: boolean;
  limitValue?: number;
}

function createMockSupabase(options?: {
  selectData?: Record<string, unknown[]>;
  counts?: Record<string, number>;
  maybeSingleData?: Record<string, unknown>;
}) {
  const inserted: InsertedRow[] = [];
  const queries: QueryCall[] = [];

  const chainable = (table: string) => {
    let filters: Record<string, unknown> = {};
    let selectFields = "";
    let countMode = false;
    let headMode = false;

    const chain: Record<string, unknown> = {
      select(fields: string, opts?: { count?: string; head?: boolean }) {
        selectFields = fields;
        if (opts?.count) countMode = true;
        if (opts?.head) headMode = true;
        return chain;
      },
      eq(field: string, value: unknown) {
        filters[field] = value;
        return chain;
      },
      order(field: string, _opts?: { ascending?: boolean }) {
        return chain;
      },
      limit(_n: number) {
        queries.push({ table, filters, selectFields });

        if (countMode || headMode) {
          const key = `${table}:${JSON.stringify(filters)}`;
          return { count: options?.counts?.[key] ?? 0 };
        }

        const data = options?.selectData?.[table] ?? [];
        return { data, error: null };
      },
      maybeSingle() {
        queries.push({ table, filters, selectFields });
        return {
          data: options?.maybeSingleData?.[table] ?? null,
          error: null,
        };
      },
    };
    return chain;
  };

  const mock = {
    from(table: string) {
      return {
        insert(rows: unknown) {
          inserted.push({ table, rows });
          return { error: null };
        },
        select(fields: string, opts?: { count?: string; head?: boolean }) {
          const c = chainable(table);
          return (c.select as CallableFunction)(fields, opts);
        },
      };
    },
    _inserted: inserted,
    _queries: queries,
  };

  return mock;
}


// ---------------------------------------------------------------------------
// insertRecoveryGraphPoints
// ---------------------------------------------------------------------------

Deno.test("insertRecoveryGraphPoints: inserts rows with correct fields", async () => {
  const mock = createMockSupabase();
  await insertRecoveryGraphPoints(
    mock as unknown as Parameters<typeof insertRecoveryGraphPoints>[0],
    "clinic-1",
    "client-1",
    "session-1",
    "right_shoulder" as BodyRegion,
    [
      { metricType: "stiffness", value: 5 },
      { metricType: "rom_flexion", value: 120 },
    ],
  );

  assertEquals(mock._inserted.length, 1);
  const rows = mock._inserted[0].rows as Array<Record<string, unknown>>;
  assertEquals(rows.length, 2);
  assertEquals(rows[0].client_id, "client-1");
  assertEquals(rows[0].clinic_id, "clinic-1");
  assertEquals(rows[0].body_region, "right_shoulder");
  assertEquals(rows[0].metric_type, "stiffness");
  assertEquals(rows[0].value, 5);
  assertEquals(rows[0].source, "session_outcome");
  assertEquals(rows[0].source_id, "session-1");
  assertExists(rows[0].recorded_at);

  assertEquals(rows[1].metric_type, "rom_flexion");
  assertEquals(rows[1].value, 120);
});

Deno.test("insertRecoveryGraphPoints: does not insert when metrics array is empty", async () => {
  const mock = createMockSupabase();
  await insertRecoveryGraphPoints(
    mock as unknown as Parameters<typeof insertRecoveryGraphPoints>[0],
    "clinic-1",
    "client-1",
    "session-1",
    "neck" as BodyRegion,
    [],
  );

  assertEquals(mock._inserted.length, 0);
});

// ---------------------------------------------------------------------------
// insertCheckinGraphPoints
// ---------------------------------------------------------------------------

Deno.test("insertCheckinGraphPoints: inserts overall feeling and region statuses", async () => {
  const mock = createMockSupabase();
  await insertCheckinGraphPoints(
    mock as unknown as Parameters<typeof insertCheckinGraphPoints>[0],
    "clinic-1",
    "client-1",
    "checkin-1",
    4,
    [
      { region: "right_shoulder" as BodyRegion, status: 3 },
      { region: "lower_back" as BodyRegion, status: 7 },
    ],
  );

  assertEquals(mock._inserted.length, 1);
  const rows = mock._inserted[0].rows as Array<Record<string, unknown>>;
  assertEquals(rows.length, 3);

  // First row: overall feeling
  assertEquals(rows[0].body_region, "overall");
  assertEquals(rows[0].metric_type, "overall_feeling");
  assertEquals(rows[0].value, 4);
  assertEquals(rows[0].source, "daily_checkin");
  assertEquals(rows[0].source_id, "checkin-1");

  // Second row: right_shoulder region status
  assertEquals(rows[1].body_region, "right_shoulder");
  assertEquals(rows[1].metric_type, "region_status");
  assertEquals(rows[1].value, 3);

  // Third row: lower_back region status
  assertEquals(rows[2].body_region, "lower_back");
  assertEquals(rows[2].metric_type, "region_status");
  assertEquals(rows[2].value, 7);
});

Deno.test("insertCheckinGraphPoints: inserts only overall feeling when no target regions", async () => {
  const mock = createMockSupabase();
  await insertCheckinGraphPoints(
    mock as unknown as Parameters<typeof insertCheckinGraphPoints>[0],
    "clinic-1",
    "client-1",
    "checkin-2",
    3,
    [],
  );

  assertEquals(mock._inserted.length, 1);
  const rows = mock._inserted[0].rows as Array<Record<string, unknown>>;
  assertEquals(rows.length, 1);
  assertEquals(rows[0].metric_type, "overall_feeling");
  assertEquals(rows[0].value, 3);
});

// ---------------------------------------------------------------------------
// queryRecoveryGraph
// ---------------------------------------------------------------------------

Deno.test("queryRecoveryGraph: maps DB rows to RecoveryGraphPoint", async () => {
  const mock = createMockSupabase({
    selectData: {
      recovery_graph: [
        {
          id: "point-1",
          client_id: "client-1",
          body_region: "right_shoulder",
          metric_type: "stiffness",
          value: 5,
          source: "session_outcome",
          source_id: "session-1",
          recorded_at: "2024-01-15T10:00:00Z",
        },
        {
          id: "point-2",
          client_id: "client-1",
          body_region: "right_shoulder",
          metric_type: "rom_flexion",
          value: 120,
          source: "assessment",
          source_id: null,
          recorded_at: "2024-01-14T10:00:00Z",
        },
      ],
    },
  });

  const result = await queryRecoveryGraph(
    mock as unknown as Parameters<typeof queryRecoveryGraph>[0],
    "client-1",
    "right_shoulder" as BodyRegion,
  );

  assertEquals(result.length, 2);
  assertEquals(result[0].id, "point-1");
  assertEquals(result[0].clientId, "client-1");
  assertEquals(result[0].bodyRegion, "right_shoulder");
  assertEquals(result[0].metricType, "stiffness");
  assertEquals(result[0].value, 5);
  assertEquals(result[0].source, "session_outcome");
  assertEquals(result[0].sourceId, "session-1");
  assertEquals(result[0].recordedAt, "2024-01-15T10:00:00Z");

  assertEquals(result[1].sourceId, null);
});

Deno.test("queryRecoveryGraph: returns empty array on error", async () => {
  const errorMock = {
    from(_table: string) {
      return {
        select(_fields: string) {
          return {
            eq(_f: string, _v: unknown) {
              return {
                eq(_f2: string, _v2: unknown) {
                  return {
                    order(_field: string, _opts: unknown) {
                      return {
                        limit(_n: number) {
                          return { data: null, error: { message: "DB error" } };
                        },
                      };
                    },
                  };
                },
              };
            },
          };
        },
      };
    },
  };

  const result = await queryRecoveryGraph(
    errorMock as unknown as Parameters<typeof queryRecoveryGraph>[0],
    "client-1",
    "right_shoulder" as BodyRegion,
  );

  assertEquals(result, []);
});

// ---------------------------------------------------------------------------
// recomputeAndInsertRecoveryScore
// ---------------------------------------------------------------------------

Deno.test("recomputeAndInsertRecoveryScore: computes and inserts score", async () => {
  // Build a mock that handles the multiple queries in recomputeAndInsertRecoveryScore
  const inserted: Array<{ table: string; rows: unknown }> = [];

  const buildChain = (resolveData: () => unknown) => {
    const chain: Record<string, unknown> = {
      select(_f: string, opts?: { count?: string; head?: boolean }) {
        if (opts?.head) {
          // Return a chain that eventually resolves to count
          return {
            eq(_f2: string, _v: unknown) {
              return {
                eq(_f3: string, _v2: unknown) {
                  return resolveData();
                },
                // For totalCount (no second eq)
                ...resolveData() as object,
              };
            },
          };
        }
        return chain;
      },
      eq(_f: string, _v: unknown) { return chain; },
      order(_f: string, _opts: unknown) { return chain; },
      limit(_n: number) { return resolveData(); },
      maybeSingle() { return resolveData(); },
    };
    return chain;
  };

  let callIndex = 0;
  const responses = [
    // outcomes query
    { data: [{ stiffness_before: 7, stiffness_after: 3 }], error: null },
    // checkins query
    { data: [{ overall_feeling: 4 }], error: null },
    // client_profiles maybeSingle
    { data: null, error: null },
    // sessions completed count
    { count: 3 },
    // sessions total count
    { count: 5 },
  ];

  const mock = {
    from(table: string) {
      return {
        insert(rows: unknown) {
          inserted.push({ table, rows });
          return { error: null };
        },
        select(fields: string, opts?: { count?: string; head?: boolean }) {
          const idx = callIndex++;
          const response = responses[idx];
          return buildChain(() => response).select!(fields, opts);
        },
      };
    },
  };

  const score = await recomputeAndInsertRecoveryScore(
    mock as unknown as Parameters<typeof recomputeAndInsertRecoveryScore>[0],
    "clinic-1",
    "client-1",
  );

  // Verify score was computed: baseline 50 + outcomeTrend + checkinTrend + adherence
  // outcomeTrend = (7-3)/10*20 = 8
  // checkinTrend = (4-3)*5 = 5
  // wearable = 0 (no wearable)
  // adherence = (3/5)*10 = 6
  // score = 50 + 8 + 5 + 0 + 6 = 69
  assertEquals(score, 69);

  // Verify the score was inserted into recovery_graph
  assertEquals(inserted.length, 1);
  assertEquals(inserted[0].table, "recovery_graph");
  const row = inserted[0].rows as Record<string, unknown>;
  assertEquals(row.client_id, "client-1");
  assertEquals(row.clinic_id, "clinic-1");
  assertEquals(row.body_region, "overall");
  assertEquals(row.metric_type, "recovery_score");
  assertEquals(row.value, 69);
  assertEquals(row.source, "computed");
  assertEquals(row.source_id, null);
});
