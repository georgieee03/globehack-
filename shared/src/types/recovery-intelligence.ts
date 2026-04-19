import type { BodyRegion, RecoveryGoal, RecoverySignalType, RecoverySignal } from "./client-profile.js";
import type { ModalityFunc, SessionConfig } from "./session-config.js";

// Re-export for convenience
export type { BodyRegion, RecoveryGoal, RecoverySignalType, RecoverySignal };

export interface PadPlacement {
  sunRegion: string;
  moonRegion: string;
  leftFuncs: ModalityFunc[];
  rightFuncs: ModalityFunc[];
  rationale: string;
}

export interface ModalityMix {
  edgeCycleDuration: number;
  intensityProfile: 'gentle' | 'moderate' | 'intense';
  pwmHot: [number, number, number];
  pwmCold: [number, number, number];
  vibMin: number;
  vibMax: number;
  led: 0 | 1;
  rationale: string;
}

export interface SessionOutcomeScore {
  sessionId: string;
  completedAt: string;
  score: number;
  config: SessionConfig;
  breakdown: {
    mobilityImproved: boolean;
    sessionEffective: boolean;
    stiffnessReduction: number;
    repeatIntent: string;
  };
}

export interface HistoryResult {
  sessionScores: SessionOutcomeScore[];
  confidence: number;
  adjustments: string[];
  bestConfig: SessionConfig | null;
}

export interface ClampingEntry {
  parameter: string;
  originalValue: number;
  clampedValue: number;
  boundary: 'min' | 'max';
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
