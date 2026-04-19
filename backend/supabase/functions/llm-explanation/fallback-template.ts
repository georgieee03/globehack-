import type { LlmExplanationRequest } from "./prompt-builder.ts";

export function generateFallbackExplanation(input: LlmExplanationRequest): string {
  const regionName = input.targetRegion.replace(/_/g, " ");
  const goalName = input.recoveryGoal.replace(/_/g, " ");
  const durationMin = Math.round(input.sessionDuration / 60);

  // Pick a representative ROM value
  const romEntries = Object.entries(input.romValues);
  const romInfo = romEntries.length > 0 ? `${romEntries[0][1]}° ROM` : "current ROM values";

  // Pick a representative asymmetry value
  const asymEntries = Object.entries(input.asymmetryScores);
  const asymInfo = asymEntries.length > 0 ? `${asymEntries[0][1]}% asymmetry` : "";

  let confidenceStatement: string;
  if (input.confidencePercent >= 70) {
    confidenceStatement = `This recommendation is supported by ${input.priorSessionCount} prior sessions.`;
  } else if (input.confidencePercent >= 50) {
    confidenceStatement = "This recommendation draws on limited session history.";
  } else {
    confidenceStatement = "This is a default protocol — more sessions will improve personalization.";
  }

  const asymClause = asymInfo ? ` and ${asymInfo}` : "";
  return `Based on ${input.clientName}'s ${regionName} assessment showing ${romInfo}${asymClause}, a ${goalName} protocol with ${durationMin}-minute sessions has been recommended. ${confidenceStatement}`;
}
