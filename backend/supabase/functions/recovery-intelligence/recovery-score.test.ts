/**
 * Unit tests for computeRecoveryScore
 */

import {
  assertAlmostEquals,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeRecoveryScore,
  type RecoveryScoreInput,
} from "./recovery-score.ts";

function makeInput(
  overrides: Partial<RecoveryScoreInput> = {},
): RecoveryScoreInput {
  return {
    recentOutcomes: [],
    recentAssessments: [],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
    ...overrides,
  };
}

Deno.test("returns baseline 50 when all inputs are neutral", () => {
  const result = computeRecoveryScore(makeInput());

  assertEquals(result.score, 50);
  assertEquals(result.breakdown.baseline, 50);
  assertEquals(result.breakdown.outcomeTrend, 0);
  assertEquals(result.breakdown.assessmentSignal, 0);
  assertEquals(result.breakdown.checkinTrend, 0);
  assertEquals(result.breakdown.wearableAdjustment, 0);
  assertEquals(result.breakdown.adherenceBonus, 0);
});

Deno.test("outcome trend raises score when stiffness drops", () => {
  const result = computeRecoveryScore(
    makeInput({
      recentOutcomes: [{ stiffness_before: 8, stiffness_after: 3 }],
    }),
  );

  assertEquals(result.breakdown.outcomeTrend, 10);
  assertEquals(result.score, 60);
});

Deno.test("check-in trend lowers score when overall feeling drops", () => {
  const result = computeRecoveryScore(
    makeInput({
      recentCheckins: [{ overall_feeling: 1 }],
    }),
  );

  assertEquals(result.breakdown.checkinTrend, -10);
  assertEquals(result.score, 40);
});

Deno.test("wearable context adds positive adjustment when HRV and sleep are strong", () => {
  const result = computeRecoveryScore(
    makeInput({
      wearableContext: { hrv: 60, strain: 5, sleepScore: 80 },
    }),
  );

  assertEquals(result.breakdown.wearableAdjustment, 10);
  assertEquals(result.score, 60);
});

Deno.test("session adherence gives a proportional bonus", () => {
  const result = computeRecoveryScore(
    makeInput({
      sessionAdherence: 0.5,
    }),
  );

  assertEquals(result.breakdown.adherenceBonus, 5);
  assertEquals(result.score, 55);
});

Deno.test("assessment signal rewards strong quality and symmetry", () => {
  const result = computeRecoveryScore(
    makeInput({
      recentAssessments: [{
        movement_quality_scores: {
          standing_front: 0.9,
          standing_side: 0.8,
          squat: 0.85,
        },
        asymmetry_scores: {
          shoulder_flexion: 6,
          hip_flexion: 8,
        },
        gait_metrics: {
          right_balance_sway: 5,
          left_balance_sway: 7,
        },
      }],
    }),
  );

  assertAlmostEquals(result.breakdown.assessmentSignal, 8.02, 1e-9);
  assertAlmostEquals(result.score, 58.02, 1e-9);
});

Deno.test("assessment signal penalizes weak quality, asymmetry, and gait stress", () => {
  const result = computeRecoveryScore(
    makeInput({
      recentAssessments: [{
        movement_quality_scores: {
          standing_front: 0.3,
          standing_side: 0.35,
        },
        asymmetry_scores: {
          shoulder_flexion: 40,
          ankle_dorsiflexion: 30,
        },
        gait_metrics: {
          right_balance_sway: 40,
          left_balance_sway: 30,
        },
      }],
    }),
  );

  assertAlmostEquals(result.breakdown.assessmentSignal, -3.9, 1e-9);
  assertAlmostEquals(result.score, 46.1, 1e-9);
});

Deno.test("final score remains clamped within 0 and 100", () => {
  const low = computeRecoveryScore(
    makeInput({
      recentOutcomes: [{ stiffness_before: 0, stiffness_after: 10 }],
      recentAssessments: [{
        movement_quality_scores: { squat: 0.1 },
        asymmetry_scores: { knee_flexion: 80 },
        gait_metrics: { right_balance_sway: 60 },
      }],
      recentCheckins: [{ overall_feeling: 1 }],
      wearableContext: { hrv: 20, strain: 5, sleepScore: 40 },
    }),
  );
  const high = computeRecoveryScore(
    makeInput({
      recentOutcomes: [{ stiffness_before: 10, stiffness_after: 0 }],
      recentAssessments: [{
        movement_quality_scores: { squat: 1, hip_hinge: 1, standing_front: 1 },
        asymmetry_scores: { knee_flexion: 0, hip_flexion: 0 },
        gait_metrics: { right_balance_sway: 0, left_balance_sway: 0 },
      }],
      recentCheckins: [{ overall_feeling: 5 }],
      wearableContext: { hrv: 60, strain: 5, sleepScore: 80 },
      sessionAdherence: 1,
    }),
  );

  assertAlmostEquals(low.score, 2.2, 1e-9);
  assertEquals(high.score, 100);
});

Deno.test("combined scenario includes the new assessment signal contribution", () => {
  const result = computeRecoveryScore(
    makeInput({
      recentOutcomes: [
        { stiffness_before: 7, stiffness_after: 4 },
        { stiffness_before: 6, stiffness_after: 3 },
      ],
      recentAssessments: [{
        movement_quality_scores: {
          standing_front: 0.75,
          standing_side: 0.7,
          single_leg_balance_right: 0.72,
          single_leg_balance_left: 0.7,
        },
        asymmetry_scores: {
          shoulder_flexion: 10,
          single_leg_balance: 12,
        },
        gait_metrics: {
          right_balance_sway: 8,
          left_balance_sway: 10,
        },
      }],
      recentCheckins: [
        { overall_feeling: 4 },
        { overall_feeling: 4 },
      ],
      wearableContext: { hrv: 55, strain: 8, sleepScore: 75 },
      sessionAdherence: 0.8,
    }),
  );

  assertEquals(result.breakdown.outcomeTrend, 6);
  assertAlmostEquals(result.breakdown.assessmentSignal, 8.19, 1e-9);
  assertEquals(result.breakdown.checkinTrend, 5);
  assertEquals(result.breakdown.wearableAdjustment, 10);
  assertEquals(result.breakdown.adherenceBonus, 8);
  assertAlmostEquals(result.score, 87.19, 1e-9);
});
