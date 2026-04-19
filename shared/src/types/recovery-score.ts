import type { OutcomeRecord } from "./outcome.js";
import type { DailyCheckinRecord } from "./daily-checkin.js";
import type { WearableContext } from "./recovery-map.js";

export interface RecoveryScoreInput {
  recentOutcomes: OutcomeRecord[];
  recentCheckins: DailyCheckinRecord[];
  wearableContext: WearableContext | null;
  sessionAdherence: number;
}

export interface RecoveryScoreResult {
  score: number;
  breakdown: {
    baseline: 50;
    outcomeTrend: number;
    checkinTrend: number;
    wearableAdjustment: number;
    adherenceBonus: number;
  };
}

export interface RecoveryGraphPoint {
  id: string;
  clientId: string;
  bodyRegion: string;
  metricType: string;
  value: number;
  source: 'assessment' | 'session_outcome' | 'daily_checkin' | 'wearable';
  sourceId: string | null;
  recordedAt: string;
}
