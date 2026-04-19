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
  recentAssessments: Array<{
    movement_quality_scores: Record<string, number> | null;
    asymmetry_scores: Record<string, number> | null;
    gait_metrics: Record<string, number> | null;
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
    assessmentSignal: number;
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
 * 3. Assessment signal (±10):
 *    movement_quality_scores are treated as 0.0–1.0 values (or 0–100 if needed)
 *    asymmetry_scores are treated as percentages where lower is better
 *
 * 4. Wearable context (±10):
 *    If HRV > 50ms: +5; if HRV < 30ms: -5
 *    If sleepScore > 70: +5; if sleepScore < 50: -5
 *    Clamped to [-10, 10]
 *
 * 5. Session adherence (0–10):
 *    adherenceBonus = sessionAdherence * 10
 *
 * Final: clamp(50 + outcomeTrend + assessmentSignal + checkinTrend + wearableAdjustment + adherenceBonus, 0, 100)
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

  // 2. Assessment signal (±10)
  let assessmentSignal = 0;
  if (input.recentAssessments.length > 0) {
    const qualityValues = input.recentAssessments.flatMap((assessment) =>
      Object.values(assessment.movement_quality_scores ?? {}).map((value) =>
        value > 1 ? value / 100 : value
      )
    );
    const asymmetryValues = input.recentAssessments.flatMap((assessment) =>
      Object.values(assessment.asymmetry_scores ?? {})
    );
    const gaitValues = input.recentAssessments.flatMap((assessment) =>
      Object.values(assessment.gait_metrics ?? {})
    );

    if (qualityValues.length > 0) {
      const averageQuality =
        qualityValues.reduce((sum, value) => sum + value, 0) /
        qualityValues.length;
      assessmentSignal += clamp((averageQuality - 0.5) * 12, -6, 6);
    }

    if (asymmetryValues.length > 0) {
      const averageAsymmetry =
        asymmetryValues.reduce((sum, value) => sum + value, 0) /
        asymmetryValues.length;
      const symmetryScore = clamp(1 - averageAsymmetry / 100, 0, 1);
      assessmentSignal += clamp((symmetryScore - 0.5) * 8, -4, 4);
    }

    if (gaitValues.length > 0) {
      const averageGaitStress =
        gaitValues.reduce((sum, value) => sum + value, 0) /
        gaitValues.length;
      const gaitScore = clamp(1 - averageGaitStress / 100, 0, 1);
      assessmentSignal += clamp((gaitScore - 0.5) * 6, -3, 3);
    }

    assessmentSignal = clamp(assessmentSignal, -10, 10);
  }

  // 3. Check-in trend (±10)
  let checkinTrend = 0;
  if (input.recentCheckins.length > 0) {
    const avgFeeling =
      input.recentCheckins.reduce((a, c) => a + c.overall_feeling, 0) /
      input.recentCheckins.length;
    checkinTrend = clamp((avgFeeling - 3) * 5, -10, 10);
  }

  // 4. Wearable context (±10)
  let wearableAdjustment = 0;
  if (input.wearableContext) {
    if (input.wearableContext.hrv > 50) wearableAdjustment += 5;
    else if (input.wearableContext.hrv < 30) wearableAdjustment -= 5;

    if (input.wearableContext.sleepScore > 70) wearableAdjustment += 5;
    else if (input.wearableContext.sleepScore < 50) wearableAdjustment -= 5;

    wearableAdjustment = clamp(wearableAdjustment, -10, 10);
  }

  // 5. Session adherence (0–10)
  const adherenceBonus = clamp(input.sessionAdherence * 10, 0, 10);

  // 6. Final score
  const score = clamp(
    50 + outcomeTrend + assessmentSignal + checkinTrend + wearableAdjustment + adherenceBonus,
    0,
    100,
  );

  return {
    score,
    breakdown: {
      baseline: 50,
      outcomeTrend,
      assessmentSignal,
      checkinTrend,
      wearableAdjustment,
      adherenceBonus,
    },
  };
}
