import type { BodyRegion, RecoveryGoal } from "./client-profile.js";

export interface LlmExplanationRequest {
  targetRegion: BodyRegion;
  recoveryGoal: RecoveryGoal;
  romValues: Record<string, number>;
  asymmetryScores: Record<string, number>;
  priorSessionCount: number;
  bestPriorOutcomeScore: number;
  confidencePercent: number;
  sessionDuration: number;
  thermalPwmHot: [number, number, number];
  thermalPwmCold: [number, number, number];
  vibMin: number;
  vibMax: number;
  ledStatus: 0 | 1;
  clientName: string;
  targetRegions: BodyRegion[];
  wearableContext?: {
    hrv: number;
    strain: number;
    sleepScore: number;
  };
}

export interface LlmExplanationResponse {
  explanation: string;
  isFallback: boolean;
}
