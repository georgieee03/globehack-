/**
 * Safe Envelope Validation for Deno Edge Functions
 * 
 * This module provides Deno-compatible validation for SessionConfig parameters
 * against safe envelope constraints. It re-implements the validation logic from
 * the shared package (@hydrascan/shared) to ensure compatibility with the Deno
 * runtime used in InsForge Edge Functions.
 * 
 * The safe envelope defines min/max ranges for all SessionConfig parameters to
 * prevent unsafe values from being sent to HydraWav3Pro devices. Region-specific
 * overrides (e.g., neck, lower_back) provide tighter constraints for sensitive
 * body regions.
 */

import {
  COMMAND_TO_PLAY_CMD,
  type HydrawavCommand,
  type PlayCmd,
} from "./device-state.ts";

export const BODY_REGIONS = [
  "right_shoulder",
  "left_shoulder",
  "right_hip",
  "left_hip",
  "lower_back",
  "upper_back",
  "right_knee",
  "left_knee",
  "neck",
  "right_calf",
  "left_calf",
  "right_arm",
  "left_arm",
  "right_foot",
  "left_foot",
] as const;

export type BodyRegion = typeof BODY_REGIONS[number];

export const MODALITY_FUNCS = [
  "leftColdBlue",
  "leftHotRed",
  "rightColdBlue",
  "rightHotRed",
] as const;

export type ModalityFunc = typeof MODALITY_FUNCS[number];

export interface SessionConfig {
  mac: string;
  sessionCount: number;
  sessionPause: number;
  sDelay: number;
  cycle1: number;
  cycle5: number;
  edgeCycleDuration: number;
  cycleRepetitions: number[];
  cycleDurations: number[];
  cyclePauses: number[];
  pauseIntervals: number[];
  leftFuncs: ModalityFunc[];
  rightFuncs: ModalityFunc[];
  pwmValues: {
    hot: [number, number, number];
    cold: [number, number, number];
  };
  playCmd: PlayCmd;
  led: 0 | 1;
  hotDrop: number;
  coldDrop: number;
  vibMin: number;
  vibMax: number;
  totalDuration: number;
}

export interface SessionConfigInput
  extends Omit<SessionConfig, "mac" | "playCmd"> {
  mac?: string;
  playCmd?: number;
}

export interface SafeEnvelope {
  pwmHotMin: number;
  pwmHotMax: number;
  pwmColdMin: number;
  pwmColdMax: number;
  vibMinFloor: number;
  vibMinCeiling: number;
  vibMaxFloor: number;
  vibMaxCeiling: number;
  hotDropMin: number;
  hotDropMax: number;
  coldDropMin: number;
  coldDropMax: number;
  edgeCycleDurationMin: number;
  edgeCycleDurationMax: number;
}

export interface SafeEnvelopeViolation {
  parameter: string;
  actual: number;
  min: number;
  max: number;
}

type ValidationResult<T> =
  | { ok: true; value: T }
  | { ok: false; errors: string[] };

const DEFAULT_SAFE_ENVELOPE: SafeEnvelope = {
  pwmHotMin: 30,
  pwmHotMax: 150,
  pwmColdMin: 100,
  pwmColdMax: 255,
  vibMinFloor: 10,
  vibMinCeiling: 50,
  vibMaxFloor: 100,
  vibMaxCeiling: 255,
  hotDropMin: 1,
  hotDropMax: 10,
  coldDropMin: 1,
  coldDropMax: 10,
  edgeCycleDurationMin: 5,
  edgeCycleDurationMax: 15,
};

export const SAFE_ENVELOPES: Record<string, Partial<SafeEnvelope>> = {
  _default: DEFAULT_SAFE_ENVELOPE,
  neck: {
    pwmHotMax: 100,
    vibMaxCeiling: 180,
  },
  lower_back: {
    pwmHotMax: 120,
    vibMaxCeiling: 200,
  },
};

const BODY_REGION_SET = new Set<string>(BODY_REGIONS);
const MODALITY_FUNC_SET = new Set<string>(MODALITY_FUNCS);
const PLAY_CMD_SET = new Set<number>([1, 2, 3, 4]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readFiniteNumber(
  record: Record<string, unknown>,
  key: string,
  errors: string[],
): number | undefined {
  const value = record[key];

  if (typeof value !== "number" || !Number.isFinite(value)) {
    errors.push(`sessionConfig.${key} must be a finite number`);
    return undefined;
  }

  return value;
}

function readNumberArray(
  record: Record<string, unknown>,
  key: string,
  errors: string[],
  options: { exactLength?: number; minLength?: number } = {},
): number[] | undefined {
  const value = record[key];

  if (!Array.isArray(value)) {
    errors.push(`sessionConfig.${key} must be an array of numbers`);
    return undefined;
  }

  if (
    typeof options.exactLength === "number" &&
    value.length !== options.exactLength
  ) {
    errors.push(
      `sessionConfig.${key} must contain exactly ${options.exactLength} values`,
    );
  }

  if (
    typeof options.minLength === "number" &&
    value.length < options.minLength
  ) {
    errors.push(
      `sessionConfig.${key} must contain at least ${options.minLength} values`,
    );
  }

  const numbers = value.filter((item) =>
    typeof item === "number" && Number.isFinite(item)
  ) as number[];

  if (numbers.length !== value.length) {
    errors.push(`sessionConfig.${key} must contain only finite numbers`);
  }

  return numbers;
}

function readModalityArray(
  record: Record<string, unknown>,
  key: string,
  errors: string[],
): ModalityFunc[] | undefined {
  const value = record[key];

  if (!Array.isArray(value) || value.length === 0) {
    errors.push(
      `sessionConfig.${key} must be a non-empty array of supported modality functions`,
    );
    return undefined;
  }

  const invalidValues = value.filter((item) =>
    typeof item !== "string" || !MODALITY_FUNC_SET.has(item)
  );

  if (invalidValues.length > 0) {
    errors.push(
      `sessionConfig.${key} contains unsupported modality functions`,
    );
  }

  return value as ModalityFunc[];
}

function readLedValue(
  record: Record<string, unknown>,
  errors: string[],
): 0 | 1 | undefined {
  const value = record.led;

  if (value !== 0 && value !== 1) {
    errors.push("sessionConfig.led must be either 0 or 1");
    return undefined;
  }

  return value;
}

function readPwmValues(
  record: Record<string, unknown>,
  errors: string[],
): SessionConfigInput["pwmValues"] | undefined {
  const value = record.pwmValues;

  if (!isRecord(value)) {
    errors.push("sessionConfig.pwmValues must be an object");
    return undefined;
  }

  const hot = readNumberArray(value, "hot", errors, { exactLength: 3 });
  const cold = readNumberArray(value, "cold", errors, { exactLength: 3 });

  if (!hot || !cold) {
    return undefined;
  }

  return {
    hot: hot as [number, number, number],
    cold: cold as [number, number, number],
  };
}

function pushRangeViolation(
  violations: SafeEnvelopeViolation[],
  parameter: string,
  actual: number,
  min: number,
  max: number,
): void {
  if (actual < min || actual > max) {
    violations.push({ parameter, actual, min, max });
  }
}

export function isBodyRegion(value: unknown): value is BodyRegion {
  return typeof value === "string" && BODY_REGION_SET.has(value);
}

export function parseSessionConfig(
  value: unknown,
): ValidationResult<SessionConfigInput> {
  if (!isRecord(value)) {
    return {
      ok: false,
      errors: ["sessionConfig must be a JSON object"],
    };
  }

  const errors: string[] = [];
  const sessionCount = readFiniteNumber(value, "sessionCount", errors);
  const sessionPause = readFiniteNumber(value, "sessionPause", errors);
  const sDelay = readFiniteNumber(value, "sDelay", errors);
  const cycle1 = readFiniteNumber(value, "cycle1", errors);
  const cycle5 = readFiniteNumber(value, "cycle5", errors);
  const edgeCycleDuration = readFiniteNumber(value, "edgeCycleDuration", errors);
  const hotDrop = readFiniteNumber(value, "hotDrop", errors);
  const coldDrop = readFiniteNumber(value, "coldDrop", errors);
  const vibMin = readFiniteNumber(value, "vibMin", errors);
  const vibMax = readFiniteNumber(value, "vibMax", errors);
  const totalDuration = readFiniteNumber(value, "totalDuration", errors);
  const led = readLedValue(value, errors);
  const cycleRepetitions = readNumberArray(value, "cycleRepetitions", errors, {
    minLength: 1,
  });
  const cycleDurations = readNumberArray(value, "cycleDurations", errors, {
    minLength: 1,
  });
  const cyclePauses = readNumberArray(value, "cyclePauses", errors, {
    minLength: 1,
  });
  const pauseIntervals = readNumberArray(value, "pauseIntervals", errors, {
    minLength: 1,
  });
  const leftFuncs = readModalityArray(value, "leftFuncs", errors);
  const rightFuncs = readModalityArray(value, "rightFuncs", errors);
  const pwmValues = readPwmValues(value, errors);

  if (typeof value.mac !== "undefined" && typeof value.mac !== "string") {
    errors.push("sessionConfig.mac must be a string when provided");
  }

  if (
    typeof value.playCmd !== "undefined" &&
    (typeof value.playCmd !== "number" || !PLAY_CMD_SET.has(value.playCmd))
  ) {
    errors.push("sessionConfig.playCmd must be one of 1, 2, 3, or 4");
  }

  if (
    typeof vibMin === "number" && typeof vibMax === "number" &&
    vibMin > vibMax
  ) {
    errors.push("sessionConfig.vibMin must be less than or equal to vibMax");
  }

  if (typeof totalDuration === "number" && totalDuration <= 0) {
    errors.push("sessionConfig.totalDuration must be greater than 0");
  }

  const choreographyLengths = [
    cycleRepetitions?.length,
    cycleDurations?.length,
    cyclePauses?.length,
    pauseIntervals?.length,
    leftFuncs?.length,
    rightFuncs?.length,
  ].filter((length): length is number => typeof length === "number");

  if (
    choreographyLengths.length > 0 &&
    new Set(choreographyLengths).size > 1
  ) {
    errors.push(
      "sessionConfig choreography arrays must all contain the same number of steps",
    );
  }

  if (errors.length > 0) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    value: {
      sessionCount: sessionCount!,
      sessionPause: sessionPause!,
      sDelay: sDelay!,
      cycle1: cycle1!,
      cycle5: cycle5!,
      edgeCycleDuration: edgeCycleDuration!,
      cycleRepetitions: cycleRepetitions!,
      cycleDurations: cycleDurations!,
      cyclePauses: cyclePauses!,
      pauseIntervals: pauseIntervals!,
      leftFuncs: leftFuncs!,
      rightFuncs: rightFuncs!,
      pwmValues: pwmValues!,
      led: led!,
      hotDrop: hotDrop!,
      coldDrop: coldDrop!,
      vibMin: vibMin!,
      vibMax: vibMax!,
      totalDuration: totalDuration!,
      mac: typeof value.mac === "string" ? value.mac : undefined,
      playCmd: typeof value.playCmd === "number" ? value.playCmd : undefined,
    },
  };
}

export function resolveSafeEnvelope(region?: BodyRegion): SafeEnvelope {
  return {
    ...DEFAULT_SAFE_ENVELOPE,
    ...(region ? SAFE_ENVELOPES[region] ?? {} : {}),
  };
}

export function validateSafeEnvelope(
  config: SessionConfigInput,
  region?: BodyRegion,
): { valid: boolean; violations: SafeEnvelopeViolation[]; envelope: SafeEnvelope } {
  const envelope = resolveSafeEnvelope(region);
  const violations: SafeEnvelopeViolation[] = [];

  config.pwmValues.hot.forEach((value, index) => {
    pushRangeViolation(
      violations,
      `pwmValues.hot[${index}]`,
      value,
      envelope.pwmHotMin,
      envelope.pwmHotMax,
    );
  });

  config.pwmValues.cold.forEach((value, index) => {
    pushRangeViolation(
      violations,
      `pwmValues.cold[${index}]`,
      value,
      envelope.pwmColdMin,
      envelope.pwmColdMax,
    );
  });

  pushRangeViolation(
    violations,
    "vibMin",
    config.vibMin,
    envelope.vibMinFloor,
    envelope.vibMinCeiling,
  );
  pushRangeViolation(
    violations,
    "vibMax",
    config.vibMax,
    envelope.vibMaxFloor,
    envelope.vibMaxCeiling,
  );
  pushRangeViolation(
    violations,
    "hotDrop",
    config.hotDrop,
    envelope.hotDropMin,
    envelope.hotDropMax,
  );
  pushRangeViolation(
    violations,
    "coldDrop",
    config.coldDrop,
    envelope.coldDropMin,
    envelope.coldDropMax,
  );
  pushRangeViolation(
    violations,
    "edgeCycleDuration",
    config.edgeCycleDuration,
    envelope.edgeCycleDurationMin,
    envelope.edgeCycleDurationMax,
  );

  return {
    valid: violations.length === 0,
    violations,
    envelope,
  };
}

export function buildStartPayload(
  deviceMac: string,
  config: SessionConfigInput,
): SessionConfig {
  const { mac: _ignoredMac, playCmd: _ignoredPlayCmd, ...rest } = config;
  return {
    ...rest,
    mac: deviceMac,
    playCmd: 1,
  };
}

export function buildMqttPayload(
  command: HydrawavCommand,
  deviceMac: string,
  config?: SessionConfigInput,
): SessionConfig | { mac: string; playCmd: PlayCmd } {
  if (command === "start") {
    if (!config) {
      throw new Error("SessionConfig is required for start commands");
    }

    return buildStartPayload(deviceMac, config);
  }

  return {
    mac: deviceMac,
    playCmd: COMMAND_TO_PLAY_CMD[command],
  };
}
