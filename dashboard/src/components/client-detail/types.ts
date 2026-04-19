import type { ClampingEntry, RecoveryMap, SessionConfig } from "@hydrascan/shared";

export interface RecommendationData {
  sessionConfig: SessionConfig;
  recoveryMap: RecoveryMap;
  recoveryScore: number;
  confidence: number;
  explanation: string;
  adjustments: string[];
  clampingLog: ClampingEntry[];
}

export interface RecommendationEnvelope {
  success?: boolean;
  action?: string;
  data?: RecommendationData;
}

export interface SessionHistoryItem {
  id: string;
  date: string;
  configSummary: string;
  outcomeRating: number | null;
  practitionerNotes?: string | null;
}
