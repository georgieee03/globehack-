import {
  BODY_REGIONS,
  type BodyRegion,
} from "../_shared/safe-envelope.ts";

export type CheckinType = "daily" | "post_activity" | "pre_visit";

export interface NormalizedTargetRegion {
  region: BodyRegion;
  status: number;
}

export interface NormalizedCheckinRequest {
  checkinType: CheckinType;
  overallFeeling: number;
  targetRegions: NormalizedTargetRegion[];
  activitySinceLast: string | null;
}

const BODY_REGION_SET = new Set<string>(BODY_REGIONS);
const CHECKIN_TYPES = new Set<CheckinType>([
  "daily",
  "post_activity",
  "pre_visit",
]);

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

function asBodyRegion(value: unknown): BodyRegion | null {
  return typeof value === "string" && BODY_REGION_SET.has(value)
    ? (value as BodyRegion)
    : null;
}

function normalizeActivity(value: unknown, errors: string[]): string | null {
  if (value == null) {
    return null;
  }

  if (typeof value !== "string") {
    errors.push("activity_since_last must be a string when provided");
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeTargetRegions(
  value: unknown,
  overallFeeling: number,
  errors: string[],
): NormalizedTargetRegion[] {
  if (value == null) {
    return [];
  }

  if (!Array.isArray(value)) {
    errors.push("target_regions must be an array");
    return [];
  }

  const targetRegions = new Map<BodyRegion, number>();

  for (const entry of value) {
    if (typeof entry === "string") {
      const region = asBodyRegion(entry);
      if (!region) {
        errors.push("target_regions contains an unsupported body region");
        continue;
      }

      targetRegions.set(region, overallFeeling);
      continue;
    }

    if (!isRecord(entry)) {
      errors.push("target_regions entries must be strings or objects");
      continue;
    }

    const region = asBodyRegion(
      readFirst(entry, ["region", "bodyRegion", "body_region"]),
    );
    if (!region) {
      errors.push("target_regions contains an unsupported body region");
      continue;
    }

    const statusValue = readFirst(entry, ["status", "severity", "value"]);
    if (statusValue == null) {
      targetRegions.set(region, overallFeeling);
      continue;
    }

    if (
      typeof statusValue !== "number" ||
      !Number.isFinite(statusValue) ||
      statusValue < 0 ||
      statusValue > 10
    ) {
      errors.push("target_regions status must be a number between 0 and 10");
      continue;
    }

    targetRegions.set(region, statusValue);
  }

  return [...targetRegions.entries()].map(([region, status]) => ({
    region,
    status,
  }));
}

export function normalizeCheckinRequest(
  payload: unknown,
): { value: NormalizedCheckinRequest | null; errors: string[] } {
  if (!isRecord(payload)) {
    return { value: null, errors: ["Request body must be a JSON object"] };
  }

  const errors: string[] = [];

  const checkinTypeValue = readFirst(payload, [
    "checkin_type",
    "checkinType",
  ]) ?? "daily";
  if (
    typeof checkinTypeValue !== "string" ||
    !CHECKIN_TYPES.has(checkinTypeValue as CheckinType)
  ) {
    errors.push("checkin_type must be 'daily', 'post_activity', or 'pre_visit'");
  }

  const overallFeelingValue = readFirst(payload, [
    "overall_feeling",
    "overallFeeling",
  ]);
  if (
    !Number.isInteger(overallFeelingValue) ||
    overallFeelingValue < 1 ||
    overallFeelingValue > 5
  ) {
    errors.push("overall_feeling must be an integer between 1 and 5");
  }

  const overallFeeling = Number.isInteger(overallFeelingValue)
    ? overallFeelingValue as number
    : 3;

  const targetRegions = normalizeTargetRegions(
    readFirst(payload, ["target_regions", "targetRegions"]),
    overallFeeling,
    errors,
  );
  const activitySinceLast = normalizeActivity(
    readFirst(payload, ["activity_since_last", "activitySinceLast"]),
    errors,
  );

  if (errors.length > 0) {
    return { value: null, errors };
  }

  return {
    value: {
      checkinType: checkinTypeValue as CheckinType,
      overallFeeling,
      targetRegions,
      activitySinceLast,
    },
    errors: [],
  };
}

export function toStoredTargetRegions(
  targetRegions: NormalizedTargetRegion[],
): Array<Record<string, unknown>> {
  return targetRegions.map((targetRegion) => ({
    region: targetRegion.region,
    status: targetRegion.status,
  }));
}
