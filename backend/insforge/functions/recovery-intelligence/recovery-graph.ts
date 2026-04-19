/**
 * Recovery Graph Data Layer
 *
 * Handles insertion and querying of time-series recovery data points
 * in the `recovery_graph` table. Supports session outcome recording,
 * daily check-in recording, and Recovery Score recomputation triggers.
 *
 * This is a Deno Edge Function module.
 *
 * Requirements: 7.1, 7.2, 7.3, 7.4, 8.5
 */

import type { InsforgeDataClient } from "../_shared/insforge-client.ts";
import type { BodyRegion } from "../_shared/safe-envelope.ts";
import {
  computeRecoveryScore,
  type RecoveryScoreInput,
} from "./recovery-score.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface RecoveryGraphPoint {
  id: string;
  clientId: string;
  bodyRegion: string;
  metricType: string;
  value: number;
  source: string;
  sourceId: string | null;
  recordedAt: string;
}

// ---------------------------------------------------------------------------
// insertRecoveryGraphPoints
// ---------------------------------------------------------------------------

/**
 * Insert recovery graph data points when a session outcome is recorded.
 *
 * Each metric (e.g., stiffness, ROM, asymmetry) is stored as a separate
 * row in the recovery_graph table with source "session_outcome".
 */
export async function insertRecoveryGraphPoints(
  insforge: InsforgeDataClient,
  clinicId: string,
  clientId: string,
  sessionId: string,
  bodyRegion: BodyRegion | "overall",
  metrics: Array<{ metricType: string; value: number }>,
): Promise<void> {
  const now = new Date().toISOString();
  const rows = metrics.map((m) => ({
    client_id: clientId,
    clinic_id: clinicId,
    body_region: bodyRegion,
    metric_type: m.metricType,
    value: m.value,
    source: "session_outcome",
    source_id: sessionId,
    recorded_at: now,
  }));

  if (rows.length > 0) {
    const { error } = await insforge.from("recovery_graph").insert(rows);
    if (error) {
      throw new Error(`Failed to insert recovery graph points: ${error.message}`);
    }
  }
}


// ---------------------------------------------------------------------------
// insertCheckinGraphPoints
// ---------------------------------------------------------------------------

/**
 * Insert recovery graph data points when a daily check-in is submitted.
 *
 * Inserts an "overall_feeling" point for the overall body region, plus
 * a "region_status" point for each target region reported in the check-in.
 */
export async function insertCheckinGraphPoints(
  insforge: InsforgeDataClient,
  clinicId: string,
  clientId: string,
  checkinId: string,
  overallFeeling: number,
  targetRegions: Array<{ region: BodyRegion; status: number }>,
): Promise<void> {
  const now = new Date().toISOString();
  const rows: Array<Record<string, unknown>> = [
    {
      client_id: clientId,
      clinic_id: clinicId,
      body_region: "overall",
      metric_type: "overall_feeling",
      value: overallFeeling,
      source: "daily_checkin",
      source_id: checkinId,
      recorded_at: now,
    },
  ];

  for (const tr of targetRegions) {
    rows.push({
      client_id: clientId,
      clinic_id: clinicId,
      body_region: tr.region,
      metric_type: "region_status",
      value: tr.status,
      source: "daily_checkin",
      source_id: checkinId,
      recorded_at: now,
    });
  }

  const { error } = await insforge.from("recovery_graph").insert(rows);
  if (error) {
    throw new Error(`Failed to insert check-in recovery graph points: ${error.message}`);
  }
}

// ---------------------------------------------------------------------------
// queryRecoveryGraph
// ---------------------------------------------------------------------------

/**
 * Query time-series data points for a client and body region.
 *
 * Returns data ordered by recorded_at descending with a configurable
 * limit (default 30 data points).
 */
export async function queryRecoveryGraph(
  insforge: InsforgeDataClient,
  clientId: string,
  bodyRegion: BodyRegion,
  limit = 30,
): Promise<RecoveryGraphPoint[]> {
  const { data, error } = await insforge
    .from("recovery_graph")
    .select(
      "id, client_id, body_region, metric_type, value, source, source_id, recorded_at",
    )
    .eq("client_id", clientId)
    .eq("body_region", bodyRegion)
    .order("recorded_at", { ascending: false })
    .limit(limit);

  if (error || !data) return [];

  return data.map((row: Record<string, unknown>) => ({
    id: row.id as string,
    clientId: row.client_id as string,
    bodyRegion: row.body_region as string,
    metricType: row.metric_type as string,
    value: row.value as number,
    source: row.source as string,
    sourceId: (row.source_id as string) ?? null,
    recordedAt: row.recorded_at as string,
  }));
}


// ---------------------------------------------------------------------------
// recomputeAndInsertRecoveryScore
// ---------------------------------------------------------------------------

/**
 * Recompute the client's Recovery Score and insert it into recovery_graph.
 *
 * Called when a session outcome or daily check-in is recorded. Fetches
 * recent outcomes, check-ins, wearable context, and session adherence,
 * then computes the score and inserts a new "recovery_score" data point.
 *
 * Returns the computed score.
 */
export async function recomputeAndInsertRecoveryScore(
  insforge: InsforgeDataClient,
  clinicId: string,
  clientId: string,
): Promise<number> {
  // Fetch recent outcomes (last 5)
  const { data: outcomes } = await insforge
    .from("outcomes")
    .select("stiffness_before, stiffness_after")
    .eq("client_id", clientId)
    .order("created_at", { ascending: false })
    .limit(5);

  // Fetch recent check-ins (last 7)
  const { data: checkins } = await insforge
    .from("daily_checkins")
    .select("overall_feeling")
    .eq("client_id", clientId)
    .order("created_at", { ascending: false })
    .limit(7);

  // Fetch wearable context from client profile
  const { data: profile } = await insforge
    .from("client_profiles")
    .select("wearable_hrv, wearable_strain, wearable_sleep_score")
    .eq("id", clientId)
    .maybeSingle();

  // Compute session adherence (completed / total recent sessions)
  const { count: completedCount } = await insforge
    .from("sessions")
    .select("id", { count: "exact", head: true })
    .eq("client_id", clientId)
    .eq("status", "completed");

  const { count: totalCount } = await insforge
    .from("sessions")
    .select("id", { count: "exact", head: true })
    .eq("client_id", clientId);

  const sessionAdherence =
    (totalCount ?? 0) > 0
      ? (completedCount ?? 0) / (totalCount ?? 0)
      : 0;

  const wearableContext =
    profile?.wearable_hrv != null
      ? {
          hrv: profile.wearable_hrv as number,
          strain: (profile.wearable_strain as number) ?? 0,
          sleepScore: (profile.wearable_sleep_score as number) ?? 0,
        }
      : null;

  const input: RecoveryScoreInput = {
    recentOutcomes: (outcomes ?? []).map(
      (o: Record<string, unknown>) => ({
        stiffness_before: o.stiffness_before as number | null,
        stiffness_after: o.stiffness_after as number | null,
      }),
    ),
    recentCheckins: (checkins ?? []).map(
      (c: Record<string, unknown>) => ({
        overall_feeling: c.overall_feeling as number,
      }),
    ),
    wearableContext,
    sessionAdherence,
  };

  const result = computeRecoveryScore(input);

  // Insert recovery score into recovery_graph
  const { error } = await insforge.from("recovery_graph").insert({
    client_id: clientId,
    clinic_id: clinicId,
    body_region: "overall",
    metric_type: "recovery_score",
    value: result.score,
    source: "computed",
    source_id: null,
    recorded_at: new Date().toISOString(),
  });

  if (error) {
    throw new Error(`Failed to insert recovery score graph point: ${error.message}`);
  }

  return result.score;
}
