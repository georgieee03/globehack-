/**
 * Unit tests for computeRecoveryScore
 *
 * Requirements: 8.1, 8.2, 8.3, 8.4
 */

import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  computeRecoveryScore,
  type RecoveryScoreInput,
} from "./recovery-score.ts";

// ---------------------------------------------------------------------------
// Baseline behavior
// ---------------------------------------------------------------------------

Deno.test("returns baseline 50 when all inputs are empty/neutral", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.score, 50);
  assertEquals(result.breakdown.baseline, 50);
  assertEquals(result.breakdown.outcomeTrend, 0);
  assertEquals(result.breakdown.checkinTrend, 0);
  assertEquals(result.breakdown.wearableAdjustment, 0);
  assertEquals(result.breakdown.adherenceBonus, 0);
});

// ---------------------------------------------------------------------------
// Outcome trend
// ---------------------------------------------------------------------------

Deno.test("outcome trend: positive stiffness reduction increases score", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [{ stiffness_before: 8, stiffness_after: 3 }],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // factor = (8 - 3) / 10 * 20 = 10
  assertEquals(result.breakdown.outcomeTrend, 10);
  assertEquals(result.score, 60);
});

Deno.test("outcome trend: negative stiffness change decreases score", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [{ stiffness_before: 2, stiffness_after: 7 }],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // factor = (2 - 7) / 10 * 20 = -10
  assertEquals(result.breakdown.outcomeTrend, -10);
  assertEquals(result.score, 40);
});

Deno.test("outcome trend: averages multiple outcomes", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [
      { stiffness_before: 10, stiffness_after: 0 }, // factor = 20
      { stiffness_before: 5, stiffness_after: 5 },  // factor = 0
    ],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // average = (20 + 0) / 2 = 10
  assertEquals(result.breakdown.outcomeTrend, 10);
});

Deno.test("outcome trend: clamped to [-20, 20]", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [{ stiffness_before: 10, stiffness_after: 0 }],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // factor = (10 - 0) / 10 * 20 = 20, clamped to 20
  assertEquals(result.breakdown.outcomeTrend, 20);
});

Deno.test("outcome trend: null stiffness values treated as 0", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [{ stiffness_before: null, stiffness_after: null }],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // factor = (0 - 0) / 10 * 20 = 0
  assertEquals(result.breakdown.outcomeTrend, 0);
});

// ---------------------------------------------------------------------------
// Check-in trend
// ---------------------------------------------------------------------------

Deno.test("checkin trend: feeling above neutral increases score", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [{ overall_feeling: 5 }],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // (5 - 3) * 5 = 10, clamped to 10
  assertEquals(result.breakdown.checkinTrend, 10);
  assertEquals(result.score, 60);
});

Deno.test("checkin trend: feeling below neutral decreases score", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [{ overall_feeling: 1 }],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // (1 - 3) * 5 = -10, clamped to -10
  assertEquals(result.breakdown.checkinTrend, -10);
  assertEquals(result.score, 40);
});

Deno.test("checkin trend: neutral feeling (3) gives 0", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [{ overall_feeling: 3 }],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.breakdown.checkinTrend, 0);
});

Deno.test("checkin trend: averages multiple check-ins", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [
      { overall_feeling: 5 },
      { overall_feeling: 1 },
    ],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // avg = 3, (3 - 3) * 5 = 0
  assertEquals(result.breakdown.checkinTrend, 0);
});

// ---------------------------------------------------------------------------
// Wearable context
// ---------------------------------------------------------------------------

Deno.test("wearable: high HRV and good sleep gives +10", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: { hrv: 60, strain: 5, sleepScore: 80 },
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.breakdown.wearableAdjustment, 10);
});

Deno.test("wearable: low HRV and poor sleep gives -10", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: { hrv: 20, strain: 5, sleepScore: 40 },
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.breakdown.wearableAdjustment, -10);
});

Deno.test("wearable: mid-range HRV and sleep gives 0", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: { hrv: 40, strain: 5, sleepScore: 60 },
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.breakdown.wearableAdjustment, 0);
});

Deno.test("wearable: boundary HRV=50 gives no adjustment", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: { hrv: 50, strain: 5, sleepScore: 60 },
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // HRV=50 is not > 50 and not < 30, so 0
  assertEquals(result.breakdown.wearableAdjustment, 0);
});

Deno.test("wearable: boundary sleepScore=70 gives no adjustment", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: { hrv: 40, strain: 5, sleepScore: 70 },
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // sleepScore=70 is not > 70 and not < 50, so 0
  assertEquals(result.breakdown.wearableAdjustment, 0);
});

Deno.test("wearable: null context gives 0", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.breakdown.wearableAdjustment, 0);
});

// ---------------------------------------------------------------------------
// Session adherence
// ---------------------------------------------------------------------------

Deno.test("adherence: full adherence gives +10", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 1.0,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.breakdown.adherenceBonus, 10);
  assertEquals(result.score, 60);
});

Deno.test("adherence: half adherence gives +5", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0.5,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.breakdown.adherenceBonus, 5);
});

Deno.test("adherence: zero adherence gives 0", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [],
    recentCheckins: [],
    wearableContext: null,
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  assertEquals(result.breakdown.adherenceBonus, 0);
});

// ---------------------------------------------------------------------------
// Final score clamping
// ---------------------------------------------------------------------------

Deno.test("final score clamped to 0 minimum", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [{ stiffness_before: 0, stiffness_after: 10 }],
    recentCheckins: [{ overall_feeling: 1 }],
    wearableContext: { hrv: 20, strain: 5, sleepScore: 40 },
    sessionAdherence: 0,
  };
  const result = computeRecoveryScore(input);
  // 50 + (-20) + (-10) + (-10) + 0 = 10
  // outcomeTrend = (0-10)/10*20 = -20
  assertEquals(result.score, 10);
});

Deno.test("final score clamped to 100 maximum", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [{ stiffness_before: 10, stiffness_after: 0 }],
    recentCheckins: [{ overall_feeling: 5 }],
    wearableContext: { hrv: 60, strain: 5, sleepScore: 80 },
    sessionAdherence: 1.0,
  };
  const result = computeRecoveryScore(input);
  // 50 + 20 + 10 + 10 + 10 = 100
  assertEquals(result.score, 100);
});

// ---------------------------------------------------------------------------
// Combined scenario
// ---------------------------------------------------------------------------

Deno.test("combined: realistic scenario with all factors", () => {
  const input: RecoveryScoreInput = {
    recentOutcomes: [
      { stiffness_before: 7, stiffness_after: 4 }, // factor = 6
      { stiffness_before: 6, stiffness_after: 3 }, // factor = 6
    ],
    recentCheckins: [
      { overall_feeling: 4 },
      { overall_feeling: 4 },
    ],
    wearableContext: { hrv: 55, strain: 8, sleepScore: 75 },
    sessionAdherence: 0.8,
  };
  const result = computeRecoveryScore(input);
  // outcomeTrend = avg(6, 6) = 6
  // checkinTrend = (4 - 3) * 5 = 5
  // wearable = +5 (hrv>50) + 5 (sleep>70) = 10
  // adherence = 0.8 * 10 = 8
  // score = 50 + 6 + 5 + 10 + 8 = 79
  assertEquals(result.breakdown.outcomeTrend, 6);
  assertEquals(result.breakdown.checkinTrend, 5);
  assertEquals(result.breakdown.wearableAdjustment, 10);
  assertEquals(result.breakdown.adherenceBonus, 8);
  assertEquals(result.score, 79);
});
