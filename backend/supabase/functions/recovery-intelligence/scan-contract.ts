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
  step: string;
  started_at: string;
  completed_at: string;
  confidence: number;
  landmarks: QuickPoseLandmarkFrame[];
  joint_angles: Record<string, number>;
  rom_values: Record<string, number>;
  asymmetry_scores: Record<string, number>;
  movement_quality_scores: Record<string, number>;
  gait_metrics: Record<string, number>;
  rep_summaries: QuickPoseRepSummary[];
  derived_metrics: Record<string, number>;
  computation_source: "feature_series" | "landmark_fallback" | "mixed";
  completeness_status: "complete" | "partial" | "insufficient_signal";
  missing_metric_keys: string[];
}

export interface QuickPoseAssessmentV2 {
  schema_version: number;
  captured_at: string;
  step_results: QuickPoseStepResult[];
  aggregate_rom_values: Record<string, number>;
  aggregate_asymmetry_scores: Record<string, number>;
  aggregate_movement_quality_scores: Record<string, number>;
  aggregate_gait_metrics: Record<string, number>;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function numericRecord(value: unknown): Record<string, number> {
  if (!isRecord(value)) return {};

  const entries = Object.entries(value).flatMap(([key, rawValue]) => {
    if (typeof rawValue === "number" && Number.isFinite(rawValue)) {
      return [[key, rawValue] as const];
    }
    return [];
  });

  return Object.fromEntries(entries);
}

function parseStepResult(value: unknown): QuickPoseStepResult | null {
  if (!isRecord(value)) return null;

  const landmarks = Array.isArray(value.landmarks)
    ? value.landmarks.flatMap((frame) => {
      if (!isRecord(frame)) return [];
      const captured_at = typeof frame.captured_at === "string"
        ? frame.captured_at
        : typeof frame.capturedAt === "string"
        ? frame.capturedAt
        : "";
      const parsedLandmarks = Array.isArray(frame.landmarks)
        ? frame.landmarks.flatMap((landmark) => {
          if (!isRecord(landmark)) return [];
          return typeof landmark.index === "number" &&
              typeof landmark.x === "number" &&
              typeof landmark.y === "number" &&
              typeof landmark.z === "number" &&
              typeof landmark.visibility === "number"
            ? [{
              index: landmark.index,
              x: landmark.x,
              y: landmark.y,
              z: landmark.z,
              visibility: landmark.visibility,
            }]
            : [];
        })
        : [];

      return [{ captured_at, landmarks: parsedLandmarks }];
    })
    : [];

  const rawRepSummaries = value.rep_summaries ?? value.repSummaries;
  const repSummaries = Array.isArray(rawRepSummaries)
    ? rawRepSummaries.flatMap((summary) => {
      if (!isRecord(summary)) return [];
      return typeof summary.movement === "string" &&
          typeof summary.count === "number"
        ? [{
          movement: summary.movement,
          count: summary.count,
          peak_angles: numericRecord(summary.peak_angles ?? summary.peakAngles),
          trough_angles: numericRecord(summary.trough_angles ?? summary.troughAngles),
        }]
        : [];
    })
    : [];

  return {
    step: typeof value.step === "string" ? value.step : "unknown",
    started_at: typeof value.started_at === "string" ? value.started_at : "",
    completed_at: typeof value.completed_at === "string" ? value.completed_at : "",
    confidence: typeof value.confidence === "number" ? value.confidence : 0,
    landmarks,
    joint_angles: numericRecord(value.joint_angles ?? value.jointAngles),
    rom_values: numericRecord(value.rom_values ?? value.romValues),
    asymmetry_scores: numericRecord(value.asymmetry_scores ?? value.asymmetryScores),
    movement_quality_scores: numericRecord(value.movement_quality_scores ?? value.movementQualityScores),
    gait_metrics: numericRecord(value.gait_metrics ?? value.gaitMetrics),
    rep_summaries: repSummaries,
    derived_metrics: numericRecord(value.derived_metrics ?? value.derivedMetrics),
    computation_source:
      value.computation_source === "feature_series" ||
        value.computation_source === "landmark_fallback" ||
        value.computation_source === "mixed"
        ? value.computation_source
        : "landmark_fallback",
    completeness_status:
      value.completeness_status === "complete" ||
        value.completeness_status === "partial" ||
        value.completeness_status === "insufficient_signal"
        ? value.completeness_status
        : "insufficient_signal",
    missing_metric_keys: Array.isArray(value.missing_metric_keys)
      ? value.missing_metric_keys.filter((entry): entry is string => typeof entry === "string")
      : [],
  };
}

export function parseQuickPoseAssessment(value: unknown): QuickPoseAssessmentV2 | null {
  if (!isRecord(value)) return null;

  const stepResults = Array.isArray(value.step_results)
    ? value.step_results.map(parseStepResult).filter((item): item is QuickPoseStepResult => item !== null)
    : [];

  const schemaVersion =
    typeof value.schema_version === "number"
      ? value.schema_version
      : stepResults.length > 0
      ? 2
      : 1;

  return {
    schema_version: schemaVersion,
    captured_at:
      typeof value.captured_at === "string"
        ? value.captured_at
        : typeof value.capturedAt === "string"
        ? value.capturedAt
        : new Date().toISOString(),
    step_results: stepResults,
    aggregate_rom_values: numericRecord(value.aggregate_rom_values ?? value.rom_values ?? value.romValues),
    aggregate_asymmetry_scores: numericRecord(
      value.aggregate_asymmetry_scores ?? value.asymmetry_scores ?? value.asymmetryScores,
    ),
    aggregate_movement_quality_scores: numericRecord(
      value.aggregate_movement_quality_scores ??
        value.movement_quality_scores ??
        value.movementQualityScores,
    ),
    aggregate_gait_metrics: numericRecord(value.aggregate_gait_metrics ?? value.gait_metrics ?? value.gaitMetrics),
  };
}

export function stepDerivedMetricValues(
  assessment: QuickPoseAssessmentV2 | null,
  keys: string[],
): number[] {
  if (!assessment) return [];

  return assessment.step_results.flatMap((step) =>
    step.completeness_status === "insufficient_signal"
      ? []
      :
    keys.flatMap((key) => {
      const value = step.derived_metrics[key];
      return typeof value === "number" ? [value] : [];
    })
  );
}

export function averageDerivedMetricForKeys(
  assessment: QuickPoseAssessmentV2 | null,
  keys: string[],
): number | null {
  const matches = stepDerivedMetricValues(assessment, keys);
  if (matches.length === 0) return null;
  return matches.reduce((sum, value) => sum + value, 0) / matches.length;
}

export function maxMetricForKeys(
  values: Record<string, number>,
  keys: string[],
): number | null {
  const matches = keys
    .map((key) => values[key])
    .filter((value): value is number => typeof value === "number");

  if (matches.length === 0) return null;
  return Math.max(...matches);
}

export function averageMetricForKeys(
  values: Record<string, number>,
  keys: string[],
): number | null {
  const matches = keys
    .map((key) => values[key])
    .filter((value): value is number => typeof value === "number");

  if (matches.length === 0) return null;
  return matches.reduce((sum, value) => sum + value, 0) / matches.length;
}
