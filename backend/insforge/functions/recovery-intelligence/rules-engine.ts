/**
 * Rules Engine for Recovery Intelligence
 *
 * Deterministic component that maps body regions to pad placements,
 * goals to modality mixes, and selects primary regions by severity.
 *
 * This is a Deno Edge Function module — all types and lookup tables
 * are inlined to avoid npm imports from the shared package.
 */

import type { BodyRegion, ModalityFunc } from "../_shared/safe-envelope.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type RecoveryGoal =
  | "mobility"
  | "warm_up"
  | "recovery"
  | "relaxation"
  | "performance_prep";

export interface PadPlacement {
  sunRegion: string;
  moonRegion: string;
  leftFuncs: ModalityFunc[];
  rightFuncs: ModalityFunc[];
  rationale: string;
}

export interface ModalityMix {
  edgeCycleDuration: number;
  intensityProfile: "gentle" | "moderate" | "intense";
  pwmHot: [number, number, number];
  pwmCold: [number, number, number];
  vibMin: number;
  vibMax: number;
  led: 0 | 1;
  rationale: string;
}

// ---------------------------------------------------------------------------
// Pad Placement Lookup Table (all 15 BodyRegion entries)
// ---------------------------------------------------------------------------

const PAD_PLACEMENT_MAP: Record<BodyRegion, PadPlacement> = {
  right_shoulder: {
    sunRegion: "Right anterior deltoid / upper trapezius",
    moonRegion: "Right posterior deltoid / infraspinatus",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Sun pad warms the anterior shoulder to promote circulation; Moon pad cools the posterior shoulder to support recovery.",
  },
  left_shoulder: {
    sunRegion: "Left anterior deltoid / upper trapezius",
    moonRegion: "Left posterior deltoid / infraspinatus",
    leftFuncs: ["leftColdBlue", "leftHotRed", "leftColdBlue"],
    rightFuncs: ["rightHotRed", "rightColdBlue", "rightHotRed"],
    rationale:
      "Sun pad warms the anterior shoulder to promote circulation; Moon pad cools the posterior shoulder to support recovery.",
  },
  right_hip: {
    sunRegion: "Right hip flexor / TFL",
    moonRegion: "Right gluteus medius",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Sun pad warms hip flexor to support mobility; Moon pad cools gluteus medius for recovery balance.",
  },
  left_hip: {
    sunRegion: "Left hip flexor / TFL",
    moonRegion: "Left gluteus medius",
    leftFuncs: ["leftColdBlue", "leftHotRed", "leftColdBlue"],
    rightFuncs: ["rightHotRed", "rightColdBlue", "rightHotRed"],
    rationale:
      "Sun pad warms hip flexor to support mobility; Moon pad cools gluteus medius for recovery balance.",
  },
  lower_back: {
    sunRegion: "Lumbar paraspinals (L3–L5)",
    moonRegion: "Sacroiliac region",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Sun pad warms lumbar paraspinals to support mobility; Moon pad cools sacroiliac region. Region-specific safe limits applied.",
  },
  upper_back: {
    sunRegion: "Thoracic paraspinals (T4–T8)",
    moonRegion: "Rhomboid / mid-trapezius",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Sun pad warms thoracic spine to support posture recovery; Moon pad cools rhomboid area.",
  },
  right_knee: {
    sunRegion: "Right quadriceps / VMO",
    moonRegion: "Right popliteal / hamstring insertion",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Sun pad warms quadriceps to support knee mobility; Moon pad cools posterior knee.",
  },
  left_knee: {
    sunRegion: "Left quadriceps / VMO",
    moonRegion: "Left popliteal / hamstring insertion",
    leftFuncs: ["leftColdBlue", "leftHotRed", "leftColdBlue"],
    rightFuncs: ["rightHotRed", "rightColdBlue", "rightHotRed"],
    rationale:
      "Sun pad warms quadriceps to support knee mobility; Moon pad cools posterior knee.",
  },
  neck: {
    sunRegion: "Posterior cervical / upper trapezius",
    moonRegion: "Lateral cervical / levator scapulae",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Gentle warming on posterior neck supports tension release; cooling on lateral neck supports comfort. Region-specific safe limits applied.",
  },
  right_calf: {
    sunRegion: "Right gastrocnemius",
    moonRegion: "Right soleus / Achilles region",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Sun pad warms gastrocnemius for circulation; Moon pad cools lower calf.",
  },
  left_calf: {
    sunRegion: "Left gastrocnemius",
    moonRegion: "Left soleus / Achilles region",
    leftFuncs: ["leftColdBlue", "leftHotRed", "leftColdBlue"],
    rightFuncs: ["rightHotRed", "rightColdBlue", "rightHotRed"],
    rationale:
      "Sun pad warms gastrocnemius for circulation; Moon pad cools lower calf.",
  },
  right_arm: {
    sunRegion: "Right biceps / anterior forearm",
    moonRegion: "Right triceps / posterior forearm",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Sun pad warms anterior arm; Moon pad cools posterior arm for balanced recovery.",
  },
  left_arm: {
    sunRegion: "Left biceps / anterior forearm",
    moonRegion: "Left triceps / posterior forearm",
    leftFuncs: ["leftColdBlue", "leftHotRed", "leftColdBlue"],
    rightFuncs: ["rightHotRed", "rightColdBlue", "rightHotRed"],
    rationale:
      "Sun pad warms anterior arm; Moon pad cools posterior arm for balanced recovery.",
  },
  right_foot: {
    sunRegion: "Right plantar fascia / arch",
    moonRegion: "Right dorsal foot / ankle",
    leftFuncs: ["leftHotRed", "leftColdBlue", "leftHotRed"],
    rightFuncs: ["rightColdBlue", "rightHotRed", "rightColdBlue"],
    rationale:
      "Sun pad warms plantar surface; Moon pad cools dorsal foot.",
  },
  left_foot: {
    sunRegion: "Left plantar fascia / arch",
    moonRegion: "Left dorsal foot / ankle",
    leftFuncs: ["leftColdBlue", "leftHotRed", "leftColdBlue"],
    rightFuncs: ["rightHotRed", "rightColdBlue", "rightHotRed"],
    rationale:
      "Sun pad warms plantar surface; Moon pad cools dorsal foot.",
  },
};

// ---------------------------------------------------------------------------
// Adjacent Regions Graph (for compensation hints)
// ---------------------------------------------------------------------------

const ADJACENT_REGIONS: Record<BodyRegion, BodyRegion[]> = {
  right_shoulder: ["neck", "upper_back", "right_arm"],
  left_shoulder: ["neck", "upper_back", "left_arm"],
  neck: ["right_shoulder", "left_shoulder", "upper_back"],
  upper_back: ["neck", "right_shoulder", "left_shoulder", "lower_back"],
  lower_back: ["upper_back", "right_hip", "left_hip"],
  right_hip: ["lower_back", "right_knee"],
  left_hip: ["lower_back", "left_knee"],
  right_knee: ["right_hip", "right_calf"],
  left_knee: ["left_hip", "left_calf"],
  right_calf: ["right_knee", "right_foot"],
  left_calf: ["left_knee", "left_foot"],
  right_arm: ["right_shoulder"],
  left_arm: ["left_shoulder"],
  right_foot: ["right_calf"],
  left_foot: ["left_calf"],
};

// ---------------------------------------------------------------------------
// Modality Mix Lookup Table (all 5 RecoveryGoal entries)
// ---------------------------------------------------------------------------

const MODALITY_MIX_MAP: Record<RecoveryGoal, ModalityMix> = {
  mobility: {
    edgeCycleDuration: 9,
    intensityProfile: "moderate",
    pwmHot: [80, 100, 120],
    pwmCold: [150, 180, 200],
    vibMin: 25,
    vibMax: 180,
    led: 1,
    rationale:
      "Moderate thermal contrast with vibro-acoustic stimulation supports joint mobility and tissue flexibility.",
  },
  warm_up: {
    edgeCycleDuration: 7,
    intensityProfile: "gentle",
    pwmHot: [60, 80, 100],
    pwmCold: [120, 140, 160],
    vibMin: 15,
    vibMax: 140,
    led: 1,
    rationale:
      "Gentle warming with light vibration prepares tissues for activity without overstimulation.",
  },
  recovery: {
    edgeCycleDuration: 9,
    intensityProfile: "moderate",
    pwmHot: [90, 110, 130],
    pwmCold: [160, 190, 220],
    vibMin: 20,
    vibMax: 160,
    led: 1,
    rationale:
      "Moderate thermal contrast with photobiomodulation supports post-activity recovery and circulation.",
  },
  relaxation: {
    edgeCycleDuration: 9,
    intensityProfile: "gentle",
    pwmHot: [50, 70, 90],
    pwmCold: [130, 150, 170],
    vibMin: 10,
    vibMax: 120,
    led: 1,
    rationale:
      "Gentle warming with low vibration promotes deep relaxation and stress reduction.",
  },
  performance_prep: {
    edgeCycleDuration: 7,
    intensityProfile: "intense",
    pwmHot: [100, 120, 140],
    pwmCold: [170, 200, 230],
    vibMin: 30,
    vibMax: 200,
    led: 1,
    rationale:
      "Intense thermal contrast with strong vibro-acoustic stimulation activates tissues for peak performance.",
  },
};

// ---------------------------------------------------------------------------
// Exported constants (for use by other modules in this Edge Function)
// ---------------------------------------------------------------------------

export { PAD_PLACEMENT_MAP, ADJACENT_REGIONS, MODALITY_MIX_MAP };

// ---------------------------------------------------------------------------
// Functions
// ---------------------------------------------------------------------------

/**
 * Select the primary body region from highlighted regions based on highest
 * severity. When severities are equal, the first region in the array wins
 * (stable sort).
 *
 * @throws Error if highlightedRegions is empty
 */
export function selectPrimaryRegion(
  highlightedRegions: Array<{ region: BodyRegion; severity: number }>,
): BodyRegion {
  if (highlightedRegions.length === 0) {
    throw new Error("highlightedRegions must not be empty");
  }

  let best = highlightedRegions[0];
  for (let i = 1; i < highlightedRegions.length; i++) {
    if (highlightedRegions[i].severity > best.severity) {
      best = highlightedRegions[i];
    }
  }
  return best.region;
}

/**
 * Map a BodyRegion to its PadPlacement, appending a compensation hint to the
 * rationale when any adjacent region has asymmetry > 10%.
 */
export function mapBodyRegionToPadPlacement(
  primaryRegion: BodyRegion,
  asymmetryScores: Record<string, number>,
  recoverySignals: Array<{
    region: BodyRegion;
    type: string;
    severity: number;
  }>,
): PadPlacement {
  const base = PAD_PLACEMENT_MAP[primaryRegion];
  const placement: PadPlacement = {
    sunRegion: base.sunRegion,
    moonRegion: base.moonRegion,
    leftFuncs: [...base.leftFuncs],
    rightFuncs: [...base.rightFuncs],
    rationale: base.rationale,
  };

  const adjacentRegions = ADJACENT_REGIONS[primaryRegion] ?? [];
  const compensationHints: string[] = [];

  for (const adjRegion of adjacentRegions) {
    const asymmetry = asymmetryScores[adjRegion];
    if (asymmetry !== undefined && asymmetry > 10) {
      const signal = recoverySignals.find((s) => s.region === adjRegion);
      const signalInfo = signal
        ? ` (${signal.type}, severity ${signal.severity})`
        : "";
      compensationHints.push(
        `Likely compensating from ${adjRegion.replace(/_/g, " ")}${signalInfo}`,
      );
    }
  }

  if (compensationHints.length > 0) {
    placement.rationale = `${placement.rationale} ${compensationHints.join(". ")}.`;
  }

  return placement;
}

/**
 * Map a RecoveryGoal to its ModalityMix configuration.
 * Returns a shallow copy so callers can mutate without affecting the lookup table.
 */
export function mapGoalToModalityMix(goal: RecoveryGoal): ModalityMix {
  const base = MODALITY_MIX_MAP[goal];
  return {
    ...base,
    pwmHot: [...base.pwmHot] as [number, number, number],
    pwmCold: [...base.pwmCold] as [number, number, number],
  };
}
