import {
  assertAlmostEquals,
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { generateRecoveryMap } from "./recovery-map.ts";

function createMockSupabase() {
  const updates: Array<{ table: string; values: Record<string, unknown>; filters: Record<string, unknown> }> = [];

  const currentAssessment = {
    id: "assessment-1",
    client_id: "client-1",
    created_at: "2026-04-18T12:00:00Z",
    quickpose_data: {
      schema_version: 2,
      captured_at: "2026-04-18T12:00:00Z",
      step_results: [{
        step: "standing_front",
        started_at: "2026-04-18T12:00:00Z",
        completed_at: "2026-04-18T12:00:05Z",
        confidence: 0.95,
        landmarks: [],
        joint_angles: {},
        rom_values: {},
        asymmetry_scores: {},
        movement_quality_scores: {
          standing_front: 0.82,
        },
        gait_metrics: {},
        rep_summaries: [],
        derived_metrics: {
          shoulder_level_offset: 6,
          frontal_posture_score: 0.82,
        },
      }],
      aggregate_rom_values: {},
      aggregate_asymmetry_scores: {
        shoulder_flexion: 14,
      },
      aggregate_movement_quality_scores: {
        standing_front: 0.82,
      },
      aggregate_gait_metrics: {},
    },
    rom_values: {},
    asymmetry_scores: {
      shoulder_flexion: 14,
    },
  };

  const previousAssessment = {
    quickpose_data: {
      schema_version: 2,
      captured_at: "2026-04-10T12:00:00Z",
      step_results: [{
        step: "standing_front",
        started_at: "2026-04-10T12:00:00Z",
        completed_at: "2026-04-10T12:00:05Z",
        confidence: 0.91,
        landmarks: [],
        joint_angles: {},
        rom_values: {},
        asymmetry_scores: {},
        movement_quality_scores: {
          standing_front: 0.7,
        },
        gait_metrics: {},
        rep_summaries: [],
        derived_metrics: {
          shoulder_level_offset: 2,
          frontal_posture_score: 0.7,
        },
      }],
      aggregate_rom_values: {},
      aggregate_asymmetry_scores: {},
      aggregate_movement_quality_scores: {
        standing_front: 0.7,
      },
      aggregate_gait_metrics: {},
    },
    rom_values: {},
    asymmetry_scores: {},
  };

  const clientProfile = {
    recovery_signals: {
      right_shoulder: { type: "stiffness", severity: 7 },
    },
    primary_regions: ["right_shoulder"],
    wearable_hrv: 55,
    wearable_strain: 28,
    wearable_sleep_score: 78,
    wearable_last_sync: "2026-04-18T08:00:00Z",
  };

  const recentSessions = [{
    id: "session-1",
    completed_at: "2026-04-17T12:00:00Z",
    session_config: {
      recoveryGoal: "mobility",
      totalDuration: 600,
    },
    outcomes: [{
      stiffness_before: 7,
      stiffness_after: 3,
      mobility_improved: true,
      session_effective: true,
      repeat_intent: "yes",
    }],
  }];

  return {
    from(table: string) {
      const filters: Record<string, unknown> = {};
      const chain = {
        select(_fields: string) {
          return chain;
        },
        eq(field: string, value: unknown) {
          filters[field] = value;
          return chain;
        },
        lt(field: string, value: unknown) {
          filters[field] = value;
          return chain;
        },
        order(_field: string, _options?: { ascending?: boolean }) {
          return chain;
        },
        limit(_count: number) {
          if (table === "assessments" && filters["client_id"] === "client-1" && "created_at" in filters) {
            return Promise.resolve({ data: [previousAssessment], error: null });
          }
          if (table === "sessions") {
            return Promise.resolve({ data: recentSessions, error: null });
          }
          return Promise.resolve({ data: [], error: null });
        },
        maybeSingle() {
          if (table === "assessments" && filters["id"] === "assessment-1") {
            return Promise.resolve({ data: currentAssessment, error: null });
          }
          if (table === "client_profiles" && filters["id"] === "client-1") {
            return Promise.resolve({ data: clientProfile, error: null });
          }
          return Promise.resolve({ data: null, error: null });
        },
        update(values: Record<string, unknown>) {
          return {
            eq(field: string, value: unknown) {
              updates.push({ table, values, filters: { [field]: value } });
              return Promise.resolve({ data: null, error: null });
            },
          };
        },
      };

      return chain;
    },
    _updates: updates,
  };
}

Deno.test("generateRecoveryMap prefers step-derived metrics when aggregate ROM keys are absent", async () => {
  const supabase = createMockSupabase();

  const result = await generateRecoveryMap(
    "client-1",
    "assessment-1",
    supabase as never,
  );

  assertEquals(result.clientId, "client-1");
  assertEquals(result.highlightedRegions.length, 1);

  const region = result.highlightedRegions[0];
  assertEquals(region.region, "right_shoulder");
  assertEquals(region.signalType, "stiffness");
  assertEquals(region.severity, 7);
  assertAlmostEquals(region.romDelta ?? 0, 4, 1e-9);
  assertEquals(region.trend, "stable");
  assertEquals(region.asymmetryFlag, true);
  assertEquals(region.compensationHint, null);

  assertExists(result.wearableContext);
  assertEquals(result.wearableContext?.hrv, 55);
  assertEquals(result.suggestedGoal, "mobility");
  assertEquals(result.priorSessions.length, 1);
  assertAlmostEquals(result.priorSessions[0].outcomeRating, 0.88, 1e-9);

  assertEquals(supabase._updates.length, 1);
  assertEquals(supabase._updates[0].table, "assessments");
  assertEquals(supabase._updates[0].filters, { id: "assessment-1" });
  assertEquals((supabase._updates[0].values.recovery_map as { clientId: string }).clientId, "client-1");
});
