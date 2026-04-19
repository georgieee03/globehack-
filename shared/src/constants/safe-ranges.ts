import type { BodyRegion } from "../types/client-profile.js";
import type { SafeEnvelope, SafeEnvelopeOverride } from "../types/safe-envelope.js";

export const DEFAULT_SAFE_ENVELOPE: SafeEnvelope = {
  pwmHotMin: 30,
  pwmHotMax: 150,
  pwmColdMin: 100,
  pwmColdMax: 255,
  vibMinFloor: 10,
  vibMinCeiling: 50,
  vibMaxFloor: 100,
  vibMaxCeiling: 255,
  hotDropMin: 1,
  hotDropMax: 10,
  coldDropMin: 1,
  coldDropMax: 10,
  edgeCycleDurationMin: 5,
  edgeCycleDurationMax: 15,
};

export const SAFE_ENVELOPES: Record<"_default" | BodyRegion, SafeEnvelopeOverride> = {
  _default: DEFAULT_SAFE_ENVELOPE,
  right_shoulder: {},
  left_shoulder: {},
  right_hip: {},
  left_hip: {},
  lower_back: {
    pwmHotMax: 120,
    vibMaxCeiling: 200,
  },
  upper_back: {},
  right_knee: {},
  left_knee: {},
  neck: {
    pwmHotMax: 100,
    vibMaxCeiling: 180,
  },
  right_calf: {},
  left_calf: {},
  right_arm: {},
  left_arm: {},
  right_foot: {},
  left_foot: {},
};
