import {
  assertArrayIncludes,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildOutcomeGraphMetrics,
  computeRomDelta,
  deriveOutcomeBodyRegion,
  normalizeOutcomeRequest,
} from "./logic.ts";

Deno.test("normalizeOutcomeRequest maps client bool/null inputs to stored outcome values", () => {
  const { value, errors } = normalizeOutcomeRequest({
    sessionID: "assessment-1",
    recordedBy: "client",
    stiffnessAfter: 4,
    sorenessAfter: 3,
    mobilityImproved: null,
    sessionEffective: true,
    repeatIntent: "no_try_different",
    clientNotes: "  Felt looser afterward  ",
  });

  assertEquals(errors, []);
  assertEquals(value?.sessionId, "assessment-1");
  assertEquals(value?.recordedBy, "client");
  assertEquals(value?.mobilityImproved, "maybe");
  assertEquals(value?.sessionEffective, "yes");
  assertEquals(value?.repeatIntent, "no");
  assertEquals(value?.notes, "Felt looser afterward");
});

Deno.test("normalizeOutcomeRequest requires boolean practitioner flags and stiffness_before", () => {
  const { errors } = normalizeOutcomeRequest({
    session_id: "session-1",
    recorded_by: "practitioner",
    stiffness_after: 4,
    mobility_improved: null,
    session_effective: "maybe",
    repeat_intent: "yes",
  });

  assertArrayIncludes(errors, [
    "stiffness_before is required for practitioner outcomes",
    "mobility_improved must be boolean for practitioner outcomes",
    "session_effective must be boolean for practitioner outcomes",
  ]);
});

Deno.test("deriveOutcomeBodyRegion prefers session config and falls back to assessment context", () => {
  assertEquals(
    deriveOutcomeBodyRegion({
      sessionConfig: { bodyRegion: "left_knee" },
      assessment: {
        recovery_map: {
          highlightedRegions: [{ region: "neck" }],
        },
      },
    }),
    "left_knee",
  );

  assertEquals(
    deriveOutcomeBodyRegion({
      sessionConfig: {},
      assessment: {
        recovery_map: {
          highlightedRegions: [{ region: "neck" }],
        },
      },
    }),
    "neck",
  );
});

Deno.test("computeRomDelta and buildOutcomeGraphMetrics use normalized rom values", () => {
  const romDelta = computeRomDelta(
    { right_hip_flexion: 120, lumbar_flexion: 84 },
    { right_hip_flexion: 110, lumbar_flexion: 80 },
  );

  assertEquals(romDelta, {
    right_hip_flexion: 10,
    lumbar_flexion: 4,
  });

  assertEquals(
    buildOutcomeGraphMetrics({
      stiffnessAfter: 4,
      sorenessAfter: 3,
      romAfter: { right_hip_flexion: 120 },
    }),
    [
      { metricType: "stiffness", value: 4 },
      { metricType: "soreness", value: 3 },
      { metricType: "rom_right_hip_flexion", value: 120 },
    ],
  );
});
