import {
  FORBIDDEN_TERMS,
  PREFERRED_REPLACEMENTS,
} from "../constants/language-guardrails.js";

export interface WellnessViolation {
  term: string;
  replacement: string;
  position: number;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function validateWellnessLanguage(text: string): {
  valid: boolean;
  violations: WellnessViolation[];
} {
  const violations: WellnessViolation[] = [];

  for (const term of FORBIDDEN_TERMS) {
    const pattern = new RegExp(escapeRegExp(term), "gi");
    for (const match of text.matchAll(pattern)) {
      violations.push({
        term,
        replacement: PREFERRED_REPLACEMENTS[term] ?? "See wellness language guide",
        position: match.index ?? 0,
      });
    }
  }

  return {
    valid: violations.length === 0,
    violations,
  };
}
