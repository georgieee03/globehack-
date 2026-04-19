import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { regionMetricMap } from "./region-metric-map.ts";

Deno.test("regionMetricMap maps shoulders to shoulder ROM and asymmetry keys", () => {
  const mapping = regionMetricMap("right_shoulder");

  assertEquals(mapping.romKeys, ["right_shoulder_flexion"]);
  assertEquals(mapping.asymmetryKeys, ["shoulder_flexion"]);
  assertEquals(mapping.movementQualityKeys, ["standing_front", "shoulder_flexion"]);
  assertEquals(mapping.derivedMetricKeys, ["shoulder_level_offset", "frontal_posture_score"]);
  assertEquals(mapping.gaitMetricKeys, []);
});

Deno.test("regionMetricMap maps lower back to spinal and posture metrics", () => {
  const mapping = regionMetricMap("lower_back");

  assertEquals(mapping.romKeys, ["spinal_flexion"]);
  assertEquals(mapping.asymmetryKeys, []);
  assertEquals(mapping.movementQualityKeys, ["standing_side", "hip_hinge"]);
  assertEquals(mapping.derivedMetricKeys, [
    "lumbar_curve_score",
    "lumbar_flexion",
    "trunk_alignment_score",
  ]);
});

Deno.test("regionMetricMap maps calf and foot regions to ankle and balance metrics", () => {
  const calf = regionMetricMap("right_calf");
  const foot = regionMetricMap("right_foot");

  assertEquals(calf.romKeys, ["right_ankle_dorsiflexion"]);
  assertEquals(calf.asymmetryKeys, ["ankle_dorsiflexion", "single_leg_balance"]);
  assertEquals(calf.gaitMetricKeys, ["right_balance_sway", "right_ankle_wobble"]);

  assertEquals(foot.romKeys, calf.romKeys);
  assertEquals(foot.asymmetryKeys, calf.asymmetryKeys);
  assertEquals(foot.gaitMetricKeys, calf.gaitMetricKeys);
});
