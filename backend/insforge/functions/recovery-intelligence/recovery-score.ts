/**
 * Recovery Score Calculator for Recovery Intelligence
 *
 * Computes a Recovery Score (0–100) from a baseline of 50, adjusted by four
 * factors: outcome trend, check-in trend, wearable context, and session
 * adherence.
 *
 * This is a Deno Edge Function module.
 */

// ---------------------------------------------------------------------------
// Types (local definitions matching shared types)
// ---------------------------------------------------------------------------

export interface RecoveryScoreInput {
  recentOutcomes: Array<{
    stiffness_before: number | null;
    stiffness_after: number | null;
  }>;
  recentCheckins: Array<{
    overall_feeling: number;
  }>;
  wearableContext: { hrv: number; strain: number; sleepScore: number } | null;
  sessionAdherence: number; // 0.0–1.0
}

export interface RecoveryScoreResult {
  score: number;
  breakdown: {
    baseline: 50;
    outcomeTrend: number;
    checkinTrend: number;
    wearableAdjustment: number;
    adherenceBonus: number;
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

// ---------------------------------------------------------------------------
// computeRecoveryScore
// ---------------------------------------------------------------------------

/**
 * Compute Recovery Score from baseline 50, adjusted by four factors.
 *
 * 1. Outcome trend (±20):
 *    For each outcome: factor = (stiffness_before - stiffness_after) / 10 * 20
 *    outcomeTrend = average of all factors, clamped to [-20, 20]
 *
 * 2. Check-in trend (±10):
 *    averageFeeling = mean of overall_feeling values (1–5)
 *    checkinTrend = (averageFeeling - 3) * 5, clamped to [-10, 10]
 *
 * 3. Wearable context (±10):
 *    If HRV > 50ms: +5; if HRV < 30ms: -5
 *    If sleepScore > 70: +5; if sleepScore < 50: -5
 *    Clamped to [-10, 10]
 *
 * 4. Session adherence (0–10):
 *    adherenceBonus = sessionAdherence * 10
 *
 * Final: clamp(50 + outcomeTrend + checkinTrend + wearableAdjustment + adherenceBonus, 0, 100)
 */
export function computeRecoveryScore(
  input: RecoveryScoreInput,
): RecoveryScoreResult {
  // 1. Outcome trend (±20)
  let outcomeTrend = 0;
  if (input.recentOutcomes.length > 0) {
    const factors = input.recentOutcomes.map((o) => {
      const before = o.stiffness_before ?? 0;
      const after = o.stiffness_after ?? 0;
      return ((before - after) / 10) * 20;
    });
    outcomeTrend = clamp(
      factors.reduce((a, b) => a + b, 0) / factors.length,
      -20,
      20,
    );
  }

  // 2. Check-in trend (±10)
  let checkinTrend = 0;
  if (input.recentCheckins.length > 0) {
    const avgFeeling =
      input.recentCheckins.reduce((a, c) => a + c.overall_feeling, 0) /
      input.recentCheckins.length;
    checkinTrend = clamp((avgFeeling - 3) * 5, -10, 10);
  }

  // 3. Wearable context (±10)
  let wearableAdjustment = 0;
  if (input.wearableContext) {
    if (input.wearableContext.hrv > 50) wearableAdjustment += 5;
    else if (input.wearableContext.hrv < 30) wearableAdjustment -= 5;

    if (input.wearableContext.sleepScore > 70) wearableAdjustment += 5;
    else if (input.wearableContext.sleepScore < 50) wearableAdjustment -= 5;

    wearableAdjustment = clamp(wearableAdjustment, -10, 10);
  }

  // 4. Session adherence (0–10)
  const adherenceBonus = clamp(input.sessionAdherence * 10, 0, 10);

  // 5. Final score
  const score = clamp(
    50 + outcomeTrend + checkinTrend + wearableAdjustment + adherenceBonus,
    0,
    100,
  );

  return {
    score,
    breakdown: {
      baseline: 50,
      outcomeTrend,
      checkinTrend,
      wearableAdjustment,
      adherenceBonus,
    },
  };
}
