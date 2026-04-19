import type { ClientListItem } from "./types";
import type { BodyRegion } from "@hydrascan/shared";
import { formatBodyRegion, formatRecoveryScore } from "@/lib/formatters";

const WELLNESS_REPLACEMENTS: Array<[RegExp, string]> = [
  [/\bpatient(s)?\b/gi, "client$1"],
  [/\btreats?\b/gi, "supports"],
  [/\bdiagnoses?\b/gi, "movement insights"],
  [/\bclinical findings?\b/gi, "movement insights"],
  [/\bmedical results?\b/gi, "movement insights"],
];

export function toWellnessText(value: string): string {
  return WELLNESS_REPLACEMENTS.reduce((text, [pattern, replacement]) => {
    return text.replace(pattern, replacement);
  }, value);
}

export function formatClientScore(score: number | null): string {
  return score == null ? "Pending" : formatRecoveryScore(score);
}

export function formatClientRegions(regions: BodyRegion[]): string[] {
  return regions.map((region) => formatBodyRegion(region));
}

export function formatClientDate(value: string | null): string {
  if (!value) return "Not yet scheduled";
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(value));
}

export function hasWellnessViolation(value: string): boolean {
  return ["patient", "patients", "treats", "treat", "diagnoses", "diagnosis", "clinical findings", "medical results"].some(
    (term) => value.toLowerCase().includes(term),
  );
}

export function sortClients(clients: ClientListItem[], sortMode: "recent" | "score") {
  return [...clients].sort((left, right) => {
    if (sortMode === "score") {
      const leftScore = left.latestRecoveryScore ?? Number.POSITIVE_INFINITY;
      const rightScore = right.latestRecoveryScore ?? Number.POSITIVE_INFINITY;
      return leftScore - rightScore;
    }

    return new Date(right.activityAt).getTime() - new Date(left.activityAt).getTime();
  });
}
