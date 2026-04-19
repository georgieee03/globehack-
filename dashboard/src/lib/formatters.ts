import type { BodyRegion, DeviceStatus, SessionStatus } from "@/types";

const FORBIDDEN_LANGUAGE = [
  /\bpatient\b/gi,
  /\btreat(s|ed|ment)?\b/gi,
  /\bdiagnos(es|ed|is)?\b/gi,
  /\bclinical finding(s)?\b/gi,
  /\bmedical result(s)?\b/gi,
];

const WELLNESS_REPLACEMENTS: Array<[RegExp, string]> = [
  [/\bpatient\b/gi, "client"],
  [/\btreat(s|ed|ment)?\b/gi, "supports"],
  [/\bdiagnos(es|ed|is)?\b/gi, "assesses"],
  [/\bclinical finding(s)?\b/gi, "movement insights"],
  [/\bmedical result(s)?\b/gi, "wellness indicators"],
  [/\bHydraWav3(Pro)?\b/g, "Hydrawav3"],
];

export function formatBodyRegion(region: string): string {
  return region.replace(/_/g, " ").replace(/\b\w/g, (char) => char.toUpperCase());
}

export function formatBodyRegions(regions: BodyRegion[] | null | undefined): string {
  if (!regions?.length) return "No target regions";
  return regions.map(formatBodyRegion).join(", ");
}

export function formatDuration(seconds: number | null | undefined): string {
  if (seconds == null || Number.isNaN(seconds)) return "Pending";
  const minutes = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (minutes <= 0) return `${secs}s`;
  return secs > 0 ? `${minutes}m ${secs}s` : `${minutes}m`;
}

export function formatConfidence(confidence: number | null | undefined): string {
  if (confidence == null || Number.isNaN(confidence)) return "0%";
  return `${Math.round(confidence * 100)}%`;
}

export function formatRecoveryScore(score: number | null | undefined): string {
  if (score == null || Number.isNaN(score)) return "No score";
  return `${Math.round(score)}/100`;
}

export function formatDateTime(value: string | null | undefined): string {
  if (!value) return "Not recorded";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Not recorded";
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(date);
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return "Not recorded";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Not recorded";
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

export function formatPercent(value: number | null | undefined): string {
  if (value == null || Number.isNaN(value)) return "N/A";
  return `${Math.round(value)}%`;
}

export function formatSignedNumber(
  value: number | null | undefined,
  unit = "",
): string {
  if (value == null || Number.isNaN(value)) return "N/A";
  const prefix = value > 0 ? "+" : "";
  return `${prefix}${value}${unit}`;
}

export function labelDeviceStatus(status: DeviceStatus): string {
  switch (status) {
    case "idle":
      return "Available";
    case "in_session":
      return "In session";
    case "paused":
      return "Paused";
    case "maintenance":
      return "Maintenance";
    case "offline":
      return "Offline";
    default:
      return status;
  }
}

export function labelSessionStatus(status: SessionStatus): string {
  switch (status) {
    case "pending":
      return "Ready to launch";
    case "active":
      return "Active";
    case "paused":
      return "Paused";
    case "completed":
      return "Completed";
    case "cancelled":
      return "Cancelled";
    case "error":
      return "Needs review";
    default:
      return status;
  }
}

export function sanitizeWellnessText(text: string): string {
  return WELLNESS_REPLACEMENTS.reduce(
    (current, [pattern, replacement]) => current.replace(pattern, replacement),
    text,
  );
}

export function findForbiddenLanguage(text: string): string[] {
  return FORBIDDEN_LANGUAGE.flatMap((pattern) => text.match(pattern) ?? []);
}

export function ensureHydrawavBrand(text: string): string {
  return text.replace(/\bHydraWav3(Pro)?\b/g, "Hydrawav3");
}
