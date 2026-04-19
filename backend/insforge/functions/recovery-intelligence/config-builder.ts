/**
 * Config Builder for Recovery Intelligence
 *
 * Assembles a complete SessionConfig from Rules Engine output, History Scorer
 * adjustments, and safe envelope constraints. Applies sensitivity reductions,
 * wearable-based adjustments, history biasing, cycle choreography generation,
 * and safe envelope clamping.
 *
 * This is a Deno Edge Function module.
 */

import {
  type BodyRegion,
  type SessionConfig,
  resolveSafeEnvelope,
} from "../_shared/safe-envelope.ts";
import type { PadPlacement, ModalityMix } from "./rules-engine.ts";
import type { HistoryResult } from "./history-scorer.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ClampingEntry {
  parameter: string;
  originalValue: number;
  clampedValue: number;
  boundary: "min" | "max";
}

export interface ConfigBuilderInput {
  padPlacement: PadPlacement;
  modalityMix: ModalityMix;
  historyResult: HistoryResult;
  sensitivities: string[];
  wearableContext?: {
    hrv: number;
    strain: number;
    sleepScore: number;
  };
  bodyRegion: BodyRegion;
  mac: string;
}

export interface ConfigBuilderOutput {
  sessionConfig: SessionConfig;
  clampingLog: ClampingEntry[];
}

// ---------------------------------------------------------------------------
// clampValue — Helper to clamp a single value and log the action
// ---------------------------------------------------------------------------

function clampValue(
  value: number,
  min: number,
  max: number,
  parameter: string,
  log: ClampingEntry[],
): number {
  if (value < min) {
    log.push({ parameter, originalValue: value, clampedValue: min, boundary: "min" });
    return min;
  }
  if (value > max) {
    log.push({ parameter, originalValue: value, clampedValue: max, boundary: "max" });
    return max;
  }
  return value;
}

// ---------------------------------------------------------------------------
// generateChoreography — Produce cycle arrays from duration and pad placement
// ---------------------------------------------------------------------------

/**
 * Generate cycle choreography arrays based on edgeCycleDuration and
 * pad placement funcs.
 *
 * Default choreography:
 * - 3 cycles per session
 * - cycleRepetitions: [1, 1, 1]
 * - cycleDurations: [edgeCycleDuration * 60, ...] (seconds)
 * - cyclePauses: [30, 30, 0] (seconds between cycles)
 * - pauseIntervals: [0, 0, 0]
 * - leftFuncs/rightFuncs: from PadPlacement, repeating the 3-element arrays
 */
export function generateChoreography(
  edgeCycleDuration: number,
  padPlacement: PadPlacement,
): {
  cycleRepetitions: number[];
  cycleDurations: number[];
  cyclePauses: number[];
  pauseIntervals: number[];
  leftFuncs: PadPlacement["leftFuncs"];
  rightFuncs: PadPlacement["rightFuncs"];
} {
  const durationSeconds = edgeCycleDuration * 60;
  return {
    cycleRepetitions: [1, 1, 1],
    cycleDurations: [durationSeconds, durationSeconds, durationSeconds],
    cyclePauses: [30, 30, 0],
    pauseIntervals: [0, 0, 0],
    leftFuncs: [...padPlacement.leftFuncs],
    rightFuncs: [...padPlacement.rightFuncs],
  };
}

// ---------------------------------------------------------------------------
// computeTotalDuration — Sum cycle durations, pauses, and session pause
// ---------------------------------------------------------------------------

/**
 * Compute total session duration in seconds.
 *
 * totalDuration = sum(cycleRepetitions[i] * cycleDurations[i])
 *               + sum(cyclePauses)
 *               + sessionPause
 */
export function computeTotalDuration(
  cycleRepetitions: number[],
  cycleDurations: number[],
  cyclePauses: number[],
  sessionPause: number,
): number {
  let total = 0;
  for (let i = 0; i < cycleRepetitions.length; i++) {
    total += cycleRepetitions[i] * cycleDurations[i];
  }
  for (const pause of cyclePauses) {
    total += pause;
  }
  total += sessionPause;
  return total;
}

// ---------------------------------------------------------------------------
// clampToSafeEnvelope — Validate and clamp SessionConfig against safe ranges
// ---------------------------------------------------------------------------

/**
 * Validate and clamp all numeric SessionConfig parameters against safe
 * envelope ranges. Uses region-specific overrides when bodyRegion is
 * 'neck' or 'lower_back'. Logs each clamping action with parameter name,
 * original value, and clamped value.
 */
export function clampToSafeEnvelope(
  config: SessionConfig,
  bodyRegion?: BodyRegion,
): ConfigBuilderOutput {
  const envelope = resolveSafeEnvelope(bodyRegion);
  const log: ClampingEntry[] = [];

  const clamped: SessionConfig = {
    ...config,
    pwmValues: {
      hot: [...config.pwmValues.hot] as [number, number, number],
      cold: [...config.pwmValues.cold] as [number, number, number],
    },
  };

  // Clamp pwmValues.hot
  for (let i = 0; i < 3; i++) {
    clamped.pwmValues.hot[i] = clampValue(
      clamped.pwmValues.hot[i],
      envelope.pwmHotMin,
      envelope.pwmHotMax,
      `pwmValues.hot[${i}]`,
      log,
    );
  }

  // Clamp pwmValues.cold
  for (let i = 0; i < 3; i++) {
    clamped.pwmValues.cold[i] = clampValue(
      clamped.pwmValues.cold[i],
      envelope.pwmColdMin,
      envelope.pwmColdMax,
      `pwmValues.cold[${i}]`,
      log,
    );
  }

  // Clamp scalar values
  clamped.vibMin = clampValue(
    clamped.vibMin,
    envelope.vibMinFloor,
    envelope.vibMinCeiling,
    "vibMin",
    log,
  );
  clamped.vibMax = clampValue(
    clamped.vibMax,
    envelope.vibMaxFloor,
    envelope.vibMaxCeiling,
    "vibMax",
    log,
  );
  clamped.hotDrop = clampValue(
    clamped.hotDrop,
    envelope.hotDropMin,
    envelope.hotDropMax,
    "hotDrop",
    log,
  );
  clamped.coldDrop = clampValue(
    clamped.coldDrop,
    envelope.coldDropMin,
    envelope.coldDropMax,
    "coldDrop",
    log,
  );
  clamped.edgeCycleDuration = clampValue(
    clamped.edgeCycleDuration,
    envelope.edgeCycleDurationMin,
    envelope.edgeCycleDurationMax,
    "edgeCycleDuration",
    log,
  );

  return { sessionConfig: clamped, clampingLog: log };
}

// ---------------------------------------------------------------------------
// serializeSessionConfig / deserializeSessionConfig — JSON round-trip
// ---------------------------------------------------------------------------

/**
 * Serialize a SessionConfig to a JSON string for the MQTT payload.
 */
export function serializeSessionConfig(config: SessionConfig): string {
  return JSON.stringify(config);
}

/**
 * Deserialize a JSON string back to a SessionConfig object.
 */
export function deserializeSessionConfig(json: string): SessionConfig {
  return JSON.parse(json) as SessionConfig;
}

// ---------------------------------------------------------------------------
// buildConfig — Full pipeline: ModalityMix → adjustments → choreography → clamp
// ---------------------------------------------------------------------------

/**
 * Build a complete SessionConfig from Rules Engine output, History Scorer
 * adjustments, and safe envelope constraints.
 *
 * Pipeline:
 * 1. Start with ModalityMix defaults for pwm, vib, led, duration
 * 2. Apply sensitivity reduction: if sensitivities includes "first_time" or
 *    "heat_sensitive", reduce pwmHot values by 20%
 * 3. Apply wearable reduction: if HRV < 30 or sleepScore < 50, reduce
 *    vibMin and vibMax by 15%
 * 4. Apply history bias: if bestConfig exists (score > 0.7), blend current
 *    values toward bestConfig by 30% (weighted average: new = current * 0.7 + best * 0.3)
 * 5. Generate cycle choreography
 * 6. Compute totalDuration
 * 7. Validate and clamp all numeric values against safe envelope
 * 8. Return ConfigBuilderOutput with sessionConfig and clampingLog
 */
export function buildConfig(input: ConfigBuilderInput): ConfigBuilderOutput {
  const {
    padPlacement,
    modalityMix,
    historyResult,
    sensitivities,
    wearableContext,
    bodyRegion,
    mac,
  } = input;

  // Step 1: Start with ModalityMix defaults
  let pwmHot: [number, number, number] = [...modalityMix.pwmHot];
  let pwmCold: [number, number, number] = [...modalityMix.pwmCold];
  let vibMin = modalityMix.vibMin;
  let vibMax = modalityMix.vibMax;

  // Step 2: Apply sensitivity reduction (20% pwmHot reduction)
  const hasSensitivity = sensitivities.some(
    (s) => s === "first_time" || s === "heat_sensitive",
  );
  if (hasSensitivity) {
    pwmHot = pwmHot.map((v) => Math.round(v * 0.8)) as [number, number, number];
  }

  // Step 3: Apply wearable reduction (15% vib reduction if HRV < 30 or sleepScore < 50)
  if (
    wearableContext &&
    (wearableContext.hrv < 30 || wearableContext.sleepScore < 50)
  ) {
    vibMin = Math.round(vibMin * 0.85);
    vibMax = Math.round(vibMax * 0.85);
  }

  // Step 4: Apply history bias (30% blend toward bestConfig if score > 0.7)
  if (historyResult.bestConfig) {
    const best = historyResult.bestConfig;
    pwmHot = pwmHot.map((v, i) =>
      Math.round(v * 0.7 + best.pwmValues.hot[i] * 0.3),
    ) as [number, number, number];
    pwmCold = pwmCold.map((v, i) =>
      Math.round(v * 0.7 + best.pwmValues.cold[i] * 0.3),
    ) as [number, number, number];
    vibMin = Math.round(vibMin * 0.7 + best.vibMin * 0.3);
    vibMax = Math.round(vibMax * 0.7 + best.vibMax * 0.3);
  }

  // Step 5: Generate cycle choreography
  const choreography = generateChoreography(
    modalityMix.edgeCycleDuration,
    padPlacement,
  );

  // Step 6: Compute totalDuration
  const sessionPause = 0;
  const totalDuration = computeTotalDuration(
    choreography.cycleRepetitions,
    choreography.cycleDurations,
    choreography.cyclePauses,
    sessionPause,
  );

  // Build the raw SessionConfig
  const rawConfig: SessionConfig = {
    mac,
    sessionCount: 1,
    sessionPause,
    sDelay: 0,
    cycle1: 1,
    cycle5: 0,
    edgeCycleDuration: modalityMix.edgeCycleDuration,
    cycleRepetitions: choreography.cycleRepetitions,
    cycleDurations: choreography.cycleDurations,
    cyclePauses: choreography.cyclePauses,
    pauseIntervals: choreography.pauseIntervals,
    leftFuncs: choreography.leftFuncs,
    rightFuncs: choreography.rightFuncs,
    pwmValues: { hot: pwmHot, cold: pwmCold },
    playCmd: 1,
    led: modalityMix.led,
    hotDrop: 5,
    coldDrop: 5,
    vibMin,
    vibMax,
    totalDuration,
  };

  // Step 7: Validate and clamp against safe envelope
  return clampToSafeEnvelope(rawConfig, bodyRegion);
}
