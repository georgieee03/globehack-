import {
  BODY_REGIONS,
  type BodyRegion,
} from "../_shared/safe-envelope.ts";

export type TriStateChoice = "yes" | "maybe" | "no";
export type RepeatIntent = TriStateChoice;

export interface NormalizedOutcomeRequest {
  sessionId: string;
  recordedBy: "client" | "practitioner";
  stiffnessBefore: number | null;
  stiffnessAfter: number;
  sorenessAfter: number | null;
  mobilityImproved: TriStateChoice | null;
  sessionEffective: TriStateChoice | null;
  readinessImproved: TriStateChoice | null;
  repeatIntent: RepeatIntent;
  romAfter: Record<string, number> | null;
  notes: string | null;
}

export interface OutcomeMetric {
  metricType: string;
  value: number;
}

interface AssessmentContext {
  body_zones?: unknown;
  recovery_map?: unknown;
  rom_values?: unknown;
}

const BODY_REGION_SET = new Set<string>(BODY_REGIONS);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readFirst(
  record: Record<string, unknown>,
  keys: string[],
): unknown {
  for (const key of keys) {
    if (key in record) {
      return record[key];
    }
  }

  return undefined;
}

function readField(
  record: Record<string, unknown>,
  keys: string[],
): { present: boolean; value: unknown } {
  for (const key of keys) {
    if (key in record) {
      return { present: true, value: record[key] };
    }
  }

  return { present: false, value: undefined };
}

function readOptionalInteger(
  record: Record<string, unknown>,
  keys: string[],
  errors: string[],
  fieldName: string,
  options: { required?: boolean; min: number; max: number },
): number | null {
  const value = readFirst(record, keys);

  if (value == null) {
    if (options.required) {
      errors.push(`${fieldName} is required`);
    }
    return null;
  }

  if (!Number.isInteger(value) || value < options.min || value > options.max) {
    errors.push(
      `${fieldName} must be an integer between ${options.min} and ${options.max}`,
    );
    return null;
  }

  return value;
}

function normalizeOptionalChoice(
  value: unknown,
  options: { nullMeansMaybe: boolean },
): TriStateChoice | null {
  if (value === undefined) {
    return null;
  }

  if (value === null) {
    return options.nullMeansMaybe ? "maybe" : null;
  }

  if (typeof value === "boolean") {
    return value ? "yes" : "no";
  }

  if (
    typeof value === "string" &&
    ["yes", "maybe", "no"].includes(value)
  ) {
    return value as TriStateChoice;
  }

  return null;
}

function normalizeRepeatIntent(value: unknown): RepeatIntent | null {
  if (value === "no_try_different") {
    return "no";
  }

  return normalizeOptionalChoice(value, { nullMeansMaybe: false });
}

function normalizeRomAfter(
  value: unknown,
  errors: string[],
): Record<string, number> | null {
  if (value == null) {
    return null;
  }

  if (!isRecord(value)) {
    errors.push("rom_after must be an object mapping joint names to numeric values");
    return null;
  }

  const romAfter: Record<string, number> = {};
  for (const [key, entry] of Object.entries(value)) {
    if (typeof entry !== "number" || !Number.isFinite(entry)) {
      errors.push("rom_after must be an object mapping joint names to numeric values");
      return null;
    }

    romAfter[key] = entry;
  }

  return romAfter;
}

function normalizeNotes(
  value: unknown,
  errors: string[],
): string | null {
  if (value == null) {
    return null;
  }

  if (typeof value !== "string") {
    errors.push("notes must be a string when provided");
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function asBodyRegion(value: unknown): BodyRegion | null {
  return typeof value === "string" && BODY_REGION_SET.has(value)
    ? (value as BodyRegion)
    : null;
}

function deriveBodyRegionFromZones(bodyZones: unknown): BodyRegion | null {
  if (!Array.isArray(bodyZones)) {
    return null;
  }

  for (const zone of bodyZones) {
    if (typeof zone === "string") {
      const region = asBodyRegion(zone);
      if (region) {
        return region;
      }
      continue;
    }

    if (isRecord(zone)) {
      const region = asBodyRegion(
        readFirst(zone, ["region", "bodyRegion", "body_region"]),
      );
      if (region) {
        return region;
      }
    }
  }

  return null;
}

function deriveBodyRegionFromRecoveryMap(recoveryMap: unknown): BodyRegion | null {
  if (!isRecord(recoveryMap) || !Array.isArray(recoveryMap.highlightedRegions)) {
    return null;
  }

  for (const regionEntry of recoveryMap.highlightedRegions) {
    if (!isRecord(regionEntry)) {
      continue;
    }

    const region = asBodyRegion(
      readFirst(regionEntry, ["region", "bodyRegion", "body_region"]),
    );
    if (region) {
      return region;
    }
  }

  return null;
}

function deriveBodyRegionFromRomValues(romValues: unknown): BodyRegion | null {
  if (!isRecord(romValues)) {
    return null;
  }

  const orderedRegions = [...BODY_REGIONS].sort((a, b) => b.length - a.length);
  for (const key of Object.keys(romValues)) {
    for (const region of orderedRegions) {
      if (key.startsWith(`${region}_`)) {
        return region;
      }
    }
  }

  return null;
}

export function normalizeOutcomeRequest(
  payload: unknown,
): { value: NormalizedOutcomeRequest | null; errors: string[] } {
  if (!isRecord(payload)) {
    return { value: null, errors: ["Request body must be a JSON object"] };
  }

  const errors: string[] = [];

  const sessionId = readFirst(payload, ["session_id", "sessionId", "sessionID"]);
  if (typeof sessionId !== "string" || sessionId.trim().length === 0) {
    errors.push("session_id is required");
  }

  const recordedBy = readFirst(payload, ["recorded_by", "recordedBy"]);
  if (recordedBy !== "client" && recordedBy !== "practitioner") {
    errors.push("recorded_by must be 'client' or 'practitioner'");
  }

  const stiffnessBefore = readOptionalInteger(
    payload,
    ["stiffness_before", "stiffnessBefore"],
    errors,
    "stiffness_before",
    { min: 0, max: 10 },
  );
  const stiffnessAfter = readOptionalInteger(
    payload,
    ["stiffness_after", "stiffnessAfter"],
    errors,
    "stiffness_after",
    { required: true, min: 0, max: 10 },
  );
  const sorenessAfter = readOptionalInteger(
    payload,
    ["soreness_after", "sorenessAfter"],
    errors,
    "soreness_after",
    { min: 0, max: 10 },
  );

  const mobilityImprovedField = readField(payload, [
    "mobility_improved",
    "mobilityImproved",
  ]);
  const mobilityImproved = normalizeOptionalChoice(
    mobilityImprovedField.value,
    { nullMeansMaybe: true },
  );
  if (mobilityImprovedField.present && mobilityImproved == null) {
    errors.push(
      "mobility_improved must be boolean, null for 'maybe', or 'yes'/'maybe'/'no'",
    );
  }

  const sessionEffectiveField = readField(payload, [
    "session_effective",
    "sessionEffective",
  ]);
  const sessionEffective = normalizeOptionalChoice(
    sessionEffectiveField.value,
    { nullMeansMaybe: true },
  );
  if (sessionEffectiveField.present && sessionEffective == null) {
    errors.push(
      "session_effective must be boolean, null for 'maybe', or 'yes'/'maybe'/'no'",
    );
  }

  const readinessImprovedField = readField(payload, [
    "readiness_improved",
    "readinessImproved",
  ]);
  const readinessImproved = normalizeOptionalChoice(
    readinessImprovedField.value,
    { nullMeansMaybe: true },
  );
  if (readinessImprovedField.present && readinessImproved == null) {
    errors.push(
      "readiness_improved must be boolean, null for 'maybe', or 'yes'/'maybe'/'no'",
    );
  }

  const repeatIntentValue = readFirst(payload, [
    "repeat_intent",
    "repeatIntent",
  ]);
  const repeatIntent = normalizeRepeatIntent(repeatIntentValue);
  if (repeatIntent == null) {
    errors.push("repeat_intent must be 'yes', 'maybe', or 'no'");
  }

  const romAfter = normalizeRomAfter(
    readFirst(payload, ["rom_after", "romAfter"]),
    errors,
  );
  const notes = normalizeNotes(
    readFirst(payload, [
      "notes",
      "client_notes",
      "clientNotes",
      "practitioner_notes",
      "practitionerNotes",
    ]),
    errors,
  );

  if (recordedBy === "client") {
    if (sorenessAfter == null) {
      errors.push("soreness_after is required for client outcomes");
    }

    if (!mobilityImprovedField.present) {
      errors.push("mobility_improved is required for client outcomes");
    }

    if (!sessionEffectiveField.present) {
      errors.push("session_effective is required for client outcomes");
    }
  }

  if (recordedBy === "practitioner") {
    if (stiffnessBefore == null) {
      errors.push("stiffness_before is required for practitioner outcomes");
    }

    if (!mobilityImprovedField.present) {
      errors.push("mobility_improved is required for practitioner outcomes");
    } else if (mobilityImproved === "maybe") {
      errors.push("mobility_improved must be boolean for practitioner outcomes");
    }

    if (!sessionEffectiveField.present) {
      errors.push("session_effective is required for practitioner outcomes");
    } else if (sessionEffective === "maybe") {
      errors.push("session_effective must be boolean for practitioner outcomes");
    }
  }

  if (errors.length > 0) {
    return { value: null, errors };
  }

  return {
    value: {
      sessionId: (sessionId as string).trim(),
      recordedBy: recordedBy as "client" | "practitioner",
      stiffnessBefore,
      stiffnessAfter: stiffnessAfter as number,
      sorenessAfter,
      mobilityImproved,
      sessionEffective,
      readinessImproved,
      repeatIntent: repeatIntent as RepeatIntent,
      romAfter,
      notes,
    },
    errors: [],
  };
}

export function computeRomDelta(
  romAfter: Record<string, number> | null,
  assessmentRomValues: unknown,
): Record<string, number> | null {
  if (!romAfter || !isRecord(assessmentRomValues)) {
    return null;
  }

  const romDelta: Record<string, number> = {};
  for (const [key, afterValue] of Object.entries(romAfter)) {
    const beforeValue = assessmentRomValues[key];
    if (typeof beforeValue === "number") {
      romDelta[key] = afterValue - beforeValue;
    }
  }

  return Object.keys(romDelta).length > 0 ? romDelta : null;
}

export function buildOutcomeGraphMetrics(
  outcome: Pick<
    NormalizedOutcomeRequest,
    "stiffnessAfter" | "sorenessAfter" | "romAfter"
  >,
): OutcomeMetric[] {
  const metrics: OutcomeMetric[] = [];

  metrics.push({
    metricType: "stiffness",
    value: outcome.stiffnessAfter,
  });

  if (outcome.sorenessAfter != null) {
    metrics.push({
      metricType: "soreness",
      value: outcome.sorenessAfter,
    });
  }

  if (outcome.romAfter) {
    for (const [jointName, value] of Object.entries(outcome.romAfter)) {
      metrics.push({
        metricType: `rom_${jointName}`,
        value,
      });
    }
  }

  return metrics;
}

export function deriveOutcomeBodyRegion(options: {
  sessionConfig?: unknown;
  assessment?: AssessmentContext | null;
}): BodyRegion | "overall" {
  const sessionRegion = isRecord(options.sessionConfig)
    ? asBodyRegion(
      readFirst(options.sessionConfig, [
        "bodyRegion",
        "body_region",
        "targetRegion",
        "target_region",
      ]),
    )
    : null;

  if (sessionRegion) {
    return sessionRegion;
  }

  const assessment = options.assessment ?? null;
  return deriveBodyRegionFromRecoveryMap(assessment?.recovery_map) ??
    deriveBodyRegionFromZones(assessment?.body_zones) ??
    deriveBodyRegionFromRomValues(assessment?.rom_values) ??
    "overall";
}
