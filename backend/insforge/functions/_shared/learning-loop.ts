import type { InsforgeDataClient } from "./insforge-client.ts";

/**
 * Learning Loop query functions.
 *
 * These enable the Recovery Intelligence Engine to correlate
 * SessionConfig parameters with outcome results, closing the
 * Know Ã¢â€ â€™ Act Ã¢â€ â€™ Learn flywheel.
 */

export interface OutcomeWithConfig {
  outcome_id: string;
  session_id: string;
  stiffness_before: number | null;
  stiffness_after: number | null;
  soreness_after: number | null;
  mobility_improved: string | null;
  session_effective: string | null;
  repeat_intent: string | null;
  rom_after: Record<string, number> | null;
  rom_delta: Record<string, number> | null;
  recorded_by: string;
  created_at: string;
  session_config: Record<string, unknown>;
  recommended_config: Record<string, unknown> | null;
  practitioner_edits: Record<string, unknown> | null;
}

/**
 * Find outcomes by SessionConfig parameters.
 * Allows the Recovery Intelligence Engine to find all outcomes for sessions
 * that used a specific body region, recovery goal, or intensity range.
 */
export async function findOutcomesByConfigParams(
  insforge: InsforgeDataClient,
  clinicId: string,
  filters: {
    bodyRegion?: string;
    recoveryGoal?: string;
    clientId?: string;
  },
  limit = 50,
): Promise<OutcomeWithConfig[]> {
  let query = insforge
    .from("outcomes")
    .select(`
      id,
      session_id,
      stiffness_before,
      stiffness_after,
      soreness_after,
      mobility_improved,
      session_effective,
      repeat_intent,
      rom_after,
      rom_delta,
      recorded_by,
      created_at,
      sessions!inner (
        session_config,
        recommended_config,
        practitioner_edits,
        clinic_id
      )
    `)
    .eq("clinic_id", clinicId)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (filters.clientId) {
    query = query.eq("client_id", filters.clientId);
  }

  const { data, error } = await query;

  if (error) {
    console.error("findOutcomesByConfigParams error:", error);
    return [];
  }

  // Filter by SessionConfig params in application layer
  // (JSONB containment queries are limited in PostgREST)
  return (data ?? [])
    .filter((row: Record<string, unknown>) => {
      const session = row.sessions as Record<string, unknown>;
      const config = session?.session_config as Record<string, unknown>;
      if (!config) return false;

      if (filters.bodyRegion && config.bodyRegion !== filters.bodyRegion) {
        return false;
      }
      if (filters.recoveryGoal && config.recoveryGoal !== filters.recoveryGoal) {
        return false;
      }
      return true;
    })
    .map((row: Record<string, unknown>) => {
      const session = row.sessions as Record<string, unknown>;
      return {
        outcome_id: row.id as string,
        session_id: row.session_id as string,
        stiffness_before: row.stiffness_before as number | null,
        stiffness_after: row.stiffness_after as number | null,
        soreness_after: row.soreness_after as number | null,
        mobility_improved: row.mobility_improved as string | null,
        session_effective: row.session_effective as string | null,
        repeat_intent: row.repeat_intent as string | null,
        rom_after: row.rom_after as Record<string, number> | null,
        rom_delta: row.rom_delta as Record<string, number> | null,
        recorded_by: row.recorded_by as string,
        created_at: row.created_at as string,
        session_config: session.session_config as Record<string, unknown>,
        recommended_config: session.recommended_config as Record<string, unknown> | null,
        practitioner_edits: session.practitioner_edits as Record<string, unknown> | null,
      };
    });
}

/**
 * Get prior session outcomes with associated SessionConfig for a client,
 * ordered by session completion date descending.
 *
 * Used by the Recovery Intelligence Engine when generating new recommendations.
 */
export async function getClientOutcomeHistory(
  insforge: InsforgeDataClient,
  clientId: string,
  limit = 10,
): Promise<OutcomeWithConfig[]> {
  const { data, error } = await insforge
    .from("outcomes")
    .select(`
      id,
      session_id,
      stiffness_before,
      stiffness_after,
      soreness_after,
      mobility_improved,
      session_effective,
      repeat_intent,
      rom_after,
      rom_delta,
      recorded_by,
      created_at,
      sessions!inner (
        session_config,
        recommended_config,
        practitioner_edits,
        completed_at
      )
    `)
    .eq("client_id", clientId)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) {
    console.error("getClientOutcomeHistory error:", error);
    return [];
  }

  return (data ?? []).map((row: Record<string, unknown>) => {
    const session = row.sessions as Record<string, unknown>;
    return {
      outcome_id: row.id as string,
      session_id: row.session_id as string,
      stiffness_before: row.stiffness_before as number | null,
      stiffness_after: row.stiffness_after as number | null,
      soreness_after: row.soreness_after as number | null,
      mobility_improved: row.mobility_improved as string | null,
      session_effective: row.session_effective as string | null,
      repeat_intent: row.repeat_intent as string | null,
      rom_after: row.rom_after as Record<string, number> | null,
      rom_delta: row.rom_delta as Record<string, number> | null,
      recorded_by: row.recorded_by as string,
      created_at: row.created_at as string,
      session_config: session.session_config as Record<string, unknown>,
      recommended_config: session.recommended_config as Record<string, unknown> | null,
      practitioner_edits: session.practitioner_edits as Record<string, unknown> | null,
    };
  });
}
