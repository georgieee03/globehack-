import type { BodyRegion, RecoveryGoal, RecoverySignalType } from "./client-profile.js";

export interface RecoveryMap {
  clientId: string;
  highlightedRegions: HighlightedRegion[];
  wearableContext: WearableContext | null;
  priorSessions: PriorSessionSummary[];
  suggestedGoal: RecoveryGoal;
  generatedAt: string;
}

export interface HighlightedRegion {
  region: BodyRegion;
  severity: number;
  signalType: RecoverySignalType;
  romDelta: number | null;
  trend: 'improving' | 'declining' | 'stable' | null;
  asymmetryFlag: boolean;
  compensationHint: string | null;
}

export interface WearableContext {
  hrv: number;
  strain: number;
  sleepScore: number;
  lastSync: string;
}

export interface PriorSessionSummary {
  date: string;
  configSummary: string;
  outcomeRating: number;
}
