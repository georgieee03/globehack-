import { DEFAULT_SAFE_ENVELOPE, SAFE_ENVELOPES } from "../constants/safe-ranges.js";
import type { BodyRegion } from "../types/client-profile.js";
import type { SessionConfig } from "../types/session-config.js";
import type {
  SafeEnvelope,
  SafeEnvelopeValidationResult,
  SafeEnvelopeViolation,
} from "../types/safe-envelope.js";

export function resolveSafeEnvelope(region?: BodyRegion): SafeEnvelope {
  if (!region) {
    return { ...DEFAULT_SAFE_ENVELOPE };
  }

  return {
    ...DEFAULT_SAFE_ENVELOPE,
    ...(SAFE_ENVELOPES[region] ?? {}),
  };
}

function createViolation(
  parameter: string,
  actual: number,
  min: number,
  max: number,
): SafeEnvelopeViolation | null {
  if (actual >= min && actual <= max) {
    return null;
  }

  return { parameter, actual, min, max };
}

export function validateSafeEnvelope(
  config: SessionConfig,
  region?: BodyRegion,
): SafeEnvelopeValidationResult {
  const envelope = resolveSafeEnvelope(region);
  const violations: SafeEnvelopeViolation[] = [];

  config.pwmValues.hot.forEach((value, index) => {
    const violation = createViolation(
      `pwmValues.hot[${index}]`,
      value,
      envelope.pwmHotMin,
      envelope.pwmHotMax,
    );

    if (violation) {
      violations.push(violation);
    }
  });

  config.pwmValues.cold.forEach((value, index) => {
    const violation = createViolation(
      `pwmValues.cold[${index}]`,
      value,
      envelope.pwmColdMin,
      envelope.pwmColdMax,
    );

    if (violation) {
      violations.push(violation);
    }
  });

  const scalarChecks: Array<[string, number, number, number]> = [
    ["vibMin", config.vibMin, envelope.vibMinFloor, envelope.vibMinCeiling],
    ["vibMax", config.vibMax, envelope.vibMaxFloor, envelope.vibMaxCeiling],
    ["hotDrop", config.hotDrop, envelope.hotDropMin, envelope.hotDropMax],
    ["coldDrop", config.coldDrop, envelope.coldDropMin, envelope.coldDropMax],
    [
      "edgeCycleDuration",
      config.edgeCycleDuration,
      envelope.edgeCycleDurationMin,
      envelope.edgeCycleDurationMax,
    ],
  ];

  for (const [parameter, actual, min, max] of scalarChecks) {
    const violation = createViolation(parameter, actual, min, max);
    if (violation) {
      violations.push(violation);
    }
  }

  if (config.vibMin > config.vibMax) {
    violations.push({
      parameter: "vibMin",
      actual: config.vibMin,
      min: envelope.vibMinFloor,
      max: Math.min(envelope.vibMinCeiling, config.vibMax),
    });
  }

  return {
    valid: violations.length === 0,
    violations,
    envelope,
  };
}
