/**
 * History Scorer for Recovery Intelligence
 *
 * Queries prior session outcomes for a client, scores each by effectiveness,
 * computes a confidence score, and identifies the best prior configuration
 * to bias future recommendations.
 *
 * This is a Deno Edge Function module.
 */

import type { InsforgeDataClient } from "../_shared/insforge-client.ts";
import type { SessionConfig } from "../_shared/safe-envelope.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SessionOutcomeScore {
  sessionId: string;
  completedAt: string;
  score: number;
  config: SessionConfig;
  breakdown: {
    mobilityImproved: boolean;
    sessionEffective: boolean;
    stiffnessReduction: number;
    repeatIntent: string;
  };
}

export interface HistoryResult {
  sessionScores: SessionOutcomeScore[];
  confidence: number;
  adjustments: string[];
  bestConfig: SessionConfig | null;
}

interface OutcomeData {
  stiffness_before: number | null;
  stiffness_after: number | null;
  mobility_improved: string | null;
  session_effective: string | null;
  repeat_intent: string | null;
}

// ---------------------------------------------------------------------------
// scoreSession Ã¢â‚¬â€ Score a single session outcome on a 0.0Ã¢â‚¬â€œ1.0 scale
// ---------------------------------------------------------------------------

/**
 * Score a single session outcome on a 0.0Ã¢â‚¬â€œ1.0 scale.
 *
 * Formula:
 *   score = 0
 *   if mobility_improved === "yes": score += 0.3
 *   if session_effective === "yes": score += 0.3
 *   stiffness_reduction = max(0, (stiffness_before - stiffness_after)) / 10
 *   score += stiffness_reduction * 0.2
 *   if repeat_intent === "yes": score += 0.2
 *
 * Result is clamped to [0.0, 1.0].
 */
export function scoreSession(outcome: OutcomeData): number {
  let score = 0;

  if (outcome.mobility_improved === "yes") score += 0.3;
  if (outcome.session_effective === "yes") score += 0.3;

  const stiffBefore = outcome.stiffness_before ?? 0;
  const stiffAfter = outcome.stiffness_after ?? 0;
  const stiffnessReduction = Math.max(0, stiffBefore - stiffAfter) / 10;
  score += stiffnessReduction * 0.2;

  if (outcome.repeat_intent === "yes") score += 0.2;

  return Math.min(1.0, Math.max(0.0, score));
}

// ---------------------------------------------------------------------------
// computeConfidence Ã¢â‚¬â€ Confidence score from session count
// ---------------------------------------------------------------------------

/**
 * Compute confidence score from session count.
 * confidence = min(1.0, sessionCount * 0.2)
 * Always in [0.0, 1.0].
 */
export function computeConfidence(sessionCount: number): number {
  return Math.min(1.0, Math.max(0.0, sessionCount * 0.2));
}

// ---------------------------------------------------------------------------
// scoreHistory Ã¢â‚¬â€ Query and score prior sessions for a client
// ---------------------------------------------------------------------------

/**
 * Query the last N completed sessions for a client, score each via
 * scoreSession, compute confidence via computeConfidence, and identify
 * the best prior config (if score > 0.7).
 *
 * Returns HistoryResult with plain-text adjustment descriptions.
 * When client has zero prior sessions, returns confidence 0.0 and
 * no history adjustments.
 */
export async function scoreHistory(
  clientId: string,
  insforge: InsforgeDataClient,
  maxSessions = 5,
): Promise<HistoryResult> {
  const { data: sessions, error } = await insforge
    .from("sessions")
    .select(`
      id,
      completed_at,
      session_config,
      outcomes (
        stiffness_before,
        stiffness_after,
        mobility_improved,
        session_effective,
        repeat_intent
      )
    `)
    .eq("client_id", clientId)
    .eq("status", "completed")
    .order("completed_at", { ascending: false })
    .limit(maxSessions);

  if (error || !sessions || sessions.length === 0) {
    return {
      sessionScores: [],
      confidence: 0.0,
      adjustments: [
        "No prior sessions Ã¢â‚¬â€ using default protocol for this goal",
      ],
      bestConfig: null,
    };
  }

  const sessionScores: SessionOutcomeScore[] = [];
  let bestScore = 0;
  let bestConfig: SessionConfig | null = null;

  for (const session of sessions) {
    const outcomes = (session.outcomes as OutcomeData[]) ?? [];
    const outcome = outcomes[0];
    if (!outcome) continue;

    const score = scoreSession(outcome);
    const config = session.session_config as unknown as SessionConfig;

    sessionScores.push({
      sessionId: session.id as string,
      completedAt: (session.completed_at as string) ?? "",
      score,
      config,
      breakdown: {
        mobilityImproved: outcome.mobility_improved === "yes",
        sessionEffective: outcome.session_effective === "yes",
        stiffnessReduction:
          Math.max(
            0,
            (outcome.stiffness_before ?? 0) - (outcome.stiffness_after ?? 0),
          ) / 10,
        repeatIntent: outcome.repeat_intent ?? "no",
      },
    });

    if (score > bestScore) {
      bestScore = score;
      bestConfig = score > 0.7 ? config : bestConfig;
    }
  }

  const confidence = computeConfidence(sessionScores.length);
  const adjustments: string[] = [];

  if (sessionScores.length === 0) {
    adjustments.push(
      "No prior sessions Ã¢â‚¬â€ using default protocol for this goal",
    );
  } else {
    adjustments.push(
      `Based on ${sessionScores.length} prior session${sessionScores.length > 1 ? "s" : ""}`,
    );
    if (bestConfig) {
      adjustments.push(
        `Biasing toward best prior session (score: ${bestScore.toFixed(2)})`,
      );
    }
    if (confidence < 0.5) {
      adjustments.push(
        "Limited history Ã¢â‚¬â€ recommendation may improve with more sessions",
      );
    }
  }

  return {
    sessionScores,
    confidence,
    adjustments,
    bestConfig,
  };
}
