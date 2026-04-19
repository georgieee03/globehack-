import type { BodyRegion } from "../_shared/safe-envelope.ts";

export interface RegionMetricMapEntry {
  romKeys: string[];
  asymmetryKeys: string[];
  movementQualityKeys: string[];
  derivedMetricKeys: string[];
  gaitMetricKeys: string[];
}

const EMPTY_MAP: RegionMetricMapEntry = {
  romKeys: [],
  asymmetryKeys: [],
  movementQualityKeys: [],
  derivedMetricKeys: [],
  gaitMetricKeys: [],
};

export const REGION_METRIC_MAP: Record<BodyRegion, RegionMetricMapEntry> = {
  right_shoulder: {
    romKeys: ["right_shoulder_flexion"],
    asymmetryKeys: ["shoulder_flexion"],
    movementQualityKeys: ["standing_front", "shoulder_flexion"],
    derivedMetricKeys: ["shoulder_level_offset", "frontal_posture_score"],
    gaitMetricKeys: [],
  },
  left_shoulder: {
    romKeys: ["left_shoulder_flexion"],
    asymmetryKeys: ["shoulder_flexion"],
    movementQualityKeys: ["standing_front", "shoulder_flexion"],
    derivedMetricKeys: ["shoulder_level_offset", "frontal_posture_score"],
    gaitMetricKeys: [],
  },
  neck: {
    romKeys: ["spinal_flexion"],
    asymmetryKeys: [],
    movementQualityKeys: ["standing_side"],
    derivedMetricKeys: ["forward_head_offset", "thoracic_curve_score", "trunk_alignment_score"],
    gaitMetricKeys: [],
  },
  upper_back: {
    romKeys: ["spinal_flexion"],
    asymmetryKeys: [],
    movementQualityKeys: ["standing_side", "hip_hinge"],
    derivedMetricKeys: ["thoracic_curve_score", "trunk_alignment_score", "lumbar_curve_score"],
    gaitMetricKeys: [],
  },
  lower_back: {
    romKeys: ["spinal_flexion"],
    asymmetryKeys: [],
    movementQualityKeys: ["standing_side", "hip_hinge"],
    derivedMetricKeys: ["lumbar_curve_score", "lumbar_flexion", "trunk_alignment_score"],
    gaitMetricKeys: [],
  },
  right_hip: {
    romKeys: ["right_hip_flexion"],
    asymmetryKeys: ["hip_flexion"],
    movementQualityKeys: ["hip_hinge", "squat", "single_leg_balance_right"],
    derivedMetricKeys: ["hip_rom_right", "squat_depth", "stability_score"],
    gaitMetricKeys: ["right_balance_sway"],
  },
  left_hip: {
    romKeys: ["left_hip_flexion"],
    asymmetryKeys: ["hip_flexion"],
    movementQualityKeys: ["hip_hinge", "squat", "single_leg_balance_left"],
    derivedMetricKeys: ["hip_rom_left", "squat_depth", "stability_score"],
    gaitMetricKeys: ["left_balance_sway"],
  },
  right_knee: {
    romKeys: ["right_knee_flexion"],
    asymmetryKeys: ["knee_flexion"],
    movementQualityKeys: ["squat"],
    derivedMetricKeys: ["knee_tracking_right", "squat_depth"],
    gaitMetricKeys: [],
  },
  left_knee: {
    romKeys: ["left_knee_flexion"],
    asymmetryKeys: ["knee_flexion"],
    movementQualityKeys: ["squat"],
    derivedMetricKeys: ["knee_tracking_left", "squat_depth"],
    gaitMetricKeys: [],
  },
  right_calf: {
    romKeys: ["right_ankle_dorsiflexion"],
    asymmetryKeys: ["ankle_dorsiflexion", "single_leg_balance"],
    movementQualityKeys: ["squat", "single_leg_balance_right"],
    derivedMetricKeys: ["ankle_mobility_right", "ankle_wobble", "stability_score"],
    gaitMetricKeys: ["right_balance_sway", "right_ankle_wobble"],
  },
  left_calf: {
    romKeys: ["left_ankle_dorsiflexion"],
    asymmetryKeys: ["ankle_dorsiflexion", "single_leg_balance"],
    movementQualityKeys: ["squat", "single_leg_balance_left"],
    derivedMetricKeys: ["ankle_mobility_left", "ankle_wobble", "stability_score"],
    gaitMetricKeys: ["left_balance_sway", "left_ankle_wobble"],
  },
  right_arm: {
    romKeys: ["right_shoulder_flexion"],
    asymmetryKeys: ["shoulder_flexion"],
    movementQualityKeys: ["shoulder_flexion"],
    derivedMetricKeys: [],
    gaitMetricKeys: [],
  },
  left_arm: {
    romKeys: ["left_shoulder_flexion"],
    asymmetryKeys: ["shoulder_flexion"],
    movementQualityKeys: ["shoulder_flexion"],
    derivedMetricKeys: [],
    gaitMetricKeys: [],
  },
  right_foot: {
    romKeys: ["right_ankle_dorsiflexion"],
    asymmetryKeys: ["ankle_dorsiflexion", "single_leg_balance"],
    movementQualityKeys: ["squat", "single_leg_balance_right"],
    derivedMetricKeys: ["ankle_mobility_right", "ankle_wobble", "stability_score"],
    gaitMetricKeys: ["right_balance_sway", "right_ankle_wobble"],
  },
  left_foot: {
    romKeys: ["left_ankle_dorsiflexion"],
    asymmetryKeys: ["ankle_dorsiflexion", "single_leg_balance"],
    movementQualityKeys: ["squat", "single_leg_balance_left"],
    derivedMetricKeys: ["ankle_mobility_left", "ankle_wobble", "stability_score"],
    gaitMetricKeys: ["left_balance_sway", "left_ankle_wobble"],
  },
};

export function regionMetricMap(region: BodyRegion): RegionMetricMapEntry {
  return REGION_METRIC_MAP[region] ?? EMPTY_MAP;
}
