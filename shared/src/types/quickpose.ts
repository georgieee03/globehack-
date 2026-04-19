export type OnboardingCaptureStep =
  | "standing_front"
  | "standing_side"
  | "shoulder_flexion"
  | "squat"
  | "hip_hinge"
  | "single_leg_balance_right"
  | "single_leg_balance_left";

export type AggregateRomKey =
  | "left_shoulder_flexion"
  | "right_shoulder_flexion"
  | "left_hip_flexion"
  | "right_hip_flexion"
  | "left_knee_flexion"
  | "right_knee_flexion"
  | "left_ankle_dorsiflexion"
  | "right_ankle_dorsiflexion"
  | "spinal_flexion";

export type AggregateAsymmetryKey =
  | "shoulder_flexion"
  | "hip_flexion"
  | "knee_flexion"
  | "ankle_dorsiflexion"
  | "single_leg_balance";

export type AggregateMovementQualityKey =
  | "standing_front"
  | "standing_side"
  | "shoulder_flexion"
  | "squat"
  | "hip_hinge"
  | "single_leg_balance_right"
  | "single_leg_balance_left";

export type AggregateGaitMetricKey =
  | "right_balance_sway"
  | "left_balance_sway"
  | "right_ankle_wobble"
  | "left_ankle_wobble";

export type QuickPoseComputationSource =
  | "feature_series"
  | "landmark_fallback"
  | "mixed";

export type QuickPoseCompletenessStatus =
  | "complete"
  | "partial"
  | "insufficient_signal";

export type QuickPoseDerivedMetricKey =
  | "shoulder_level_offset"
  | "hip_level_offset"
  | "knee_alignment_offset"
  | "frontal_posture_score"
  | "forward_head_offset"
  | "thoracic_curve_score"
  | "lumbar_curve_score"
  | "trunk_alignment_score"
  | "squat_depth"
  | "knee_tracking_left"
  | "knee_tracking_right"
  | "trunk_lean"
  | "ankle_mobility_left"
  | "ankle_mobility_right"
  | "hip_rom_left"
  | "hip_rom_right"
  | "lumbar_flexion"
  | "hamstring_flexibility_left"
  | "hamstring_flexibility_right"
  | "stability_score"
  | "ankle_wobble"
  | "compensation_score"
  | "sway_distance"
  | "balance_asymmetry";

export interface QuickPoseLandmark {
  index: number;
  x: number;
  y: number;
  z: number;
  visibility: number;
}

export interface QuickPoseLandmarkFrame {
  captured_at: string;
  landmarks: QuickPoseLandmark[];
}

export interface QuickPoseRepSummary {
  movement: string;
  count: number;
  peak_angles: Record<string, number>;
  trough_angles: Record<string, number>;
}

export interface QuickPoseStepResult {
  step: OnboardingCaptureStep;
  started_at: string;
  completed_at: string;
  confidence: number;
  landmarks: QuickPoseLandmarkFrame[];
  joint_angles: Record<string, number>;
  rom_values: Partial<Record<AggregateRomKey, number>>;
  asymmetry_scores: Partial<Record<AggregateAsymmetryKey, number>>;
  movement_quality_scores: Partial<Record<AggregateMovementQualityKey, number>>;
  gait_metrics: Partial<Record<AggregateGaitMetricKey, number>>;
  rep_summaries: QuickPoseRepSummary[];
  derived_metrics: Partial<Record<QuickPoseDerivedMetricKey, number>>;
  computation_source: QuickPoseComputationSource;
  completeness_status: QuickPoseCompletenessStatus;
  missing_metric_keys: string[];
}

export interface QuickPoseAssessmentV2 {
  schema_version: 2;
  captured_at: string;
  step_results: QuickPoseStepResult[];
  aggregate_rom_values: Partial<Record<AggregateRomKey, number>>;
  aggregate_asymmetry_scores: Partial<Record<AggregateAsymmetryKey, number>>;
  aggregate_movement_quality_scores: Partial<Record<AggregateMovementQualityKey, number>>;
  aggregate_gait_metrics: Partial<Record<AggregateGaitMetricKey, number>>;
}
