import type { BodyRegion } from "../_shared/safe-envelope.ts";

type RecoveryGoal = "mobility" | "warm_up" | "recovery" | "relaxation" | "performance_prep";

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
  wearableContext?: { hrv: number; strain: number; sleepScore: number };
}

export function buildPrompt(input: LlmExplanationRequest): string {
  const systemMessage = `You are a wellness recovery assistant. Use ONLY wellness and recovery language. 
NEVER use these terms: patient, diagnoses, treats, cure, medical, clinical, prescription, medication, drug, heal, therapy, symptom, clinical finding, medical result.
Instead use: client, assessment, supports, recovery, wellness, session guidance, movement insight, wellness indicator.
Explain in 2-3 sentences why this protocol was recommended for this specific client. Reference specific data points.`;

  const regionNames = input.targetRegions.map(r => r.replace(/_/g, " ")).join(", ");
  const romEntries = Object.entries(input.romValues).map(([k, v]) => `${k}: ${v}°`).join(", ");
  const asymEntries = Object.entries(input.asymmetryScores).map(([k, v]) => `${k}: ${v}%`).join(", ");

  const clientContext = `Client: ${input.clientName}
Target regions: ${regionNames}
ROM values: ${romEntries || "none recorded"}
Asymmetry scores: ${asymEntries || "none recorded"}`;

  const wearableInfo = input.wearableContext
    ? `Wearable data: HRV ${input.wearableContext.hrv}ms, strain ${input.wearableContext.strain}, sleep score ${input.wearableContext.sleepScore}/100`
    : "No wearable data available";

  const recommendationContext = `Recovery goal: ${input.recoveryGoal.replace(/_/g, " ")}
Session duration: ${Math.round(input.sessionDuration / 60)} minutes
Thermal PWM (hot): ${input.thermalPwmHot.join(", ")}
Thermal PWM (cold): ${input.thermalPwmCold.join(", ")}
Vibration range: ${input.vibMin}–${input.vibMax}
LED (photobiomodulation): ${input.ledStatus === 1 ? "active" : "inactive"}`;

  const historyContext = `Prior sessions: ${input.priorSessionCount}
Best prior outcome score: ${(input.bestPriorOutcomeScore * 100).toFixed(0)}%
Confidence: ${input.confidencePercent.toFixed(0)}%`;

  return `${systemMessage}\n\n${clientContext}\n${wearableInfo}\n\n${recommendationContext}\n\n${historyContext}\n\nExplain in 2-3 sentences why this protocol was recommended.`;
}
