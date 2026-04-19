/**
 * Recovery Map Generator for Recovery Intelligence
 *
 * Generates a structured 60-second practitioner summary containing highlighted
 * body regions with severity, signal type, ROM delta, asymmetry flags,
 * compensation hints, wearable context, prior session outcomes, and a
 * suggested recovery goal.
 *
 * This is a Deno Edge Function module.
 */

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import type { BodyRegion } from "../_shared/safe-envelope.ts";
import type { RecoveryGoal } from "./rules-engine.ts";

// ---------------------------------------------------------------------------
// Types (local definitions matching shared types)
// ---------------------------------------------------------------------------

export interface HighlightedRegion {
  region: BodyRegion;
  severity: number;
  signalType: string;
  romDelta: number | null;
  trend: "improving" | "declining" | "stable" | null;
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

export interface RecoveryMap {
  clientId: string;
  highlightedRegions: HighlightedRegion[];
  wearableContext: WearableContext | null;
  priorSessions: PriorSessionSummary[];
  suggestedGoal: RecoveryGoal;
  generatedAt: string;
}

// ---------------------------------------------------------------------------
// Bilateral pairs for asymmetry checking
// ---------------------------------------------------------------------------

const BILATERAL_PAIRS: [BodyRegion, BodyRegion][] = [
  ["right_shoulder", "left_shoulder"],
  ["right_hip", "left_hip"],
  ["right_knee", "left_knee"],
  ["right_calf", "left_calf"],
  ["right_arm", "left_arm"],
  ["right_foot", "left_foot"],
];

// ---------------------------------------------------------------------------
// Adjacent regions for compensation hints
// ---------------------------------------------------------------------------

const ADJACENT_REGIONS: Record<BodyRegion, BodyRegion[]> = {
  right_shoulder: ["neck", "upper_back", "right_arm"],
  left_shoulder: ["neck", "upper_back", "left_arm"],
  neck: ["right_shoulder", "left_shoulder", "upper_back"],
  upper_back: ["neck", "right_shoulder", "left_shoulder", "lower_back"],
  lower_back: ["upper_back", "right_hip", "left_hip"],
  right_hip: ["lower_back", "right_knee"],
  left_hip: ["lower_back", "left_knee"],
  right_knee: ["right_hip", "right_calf"],
  left_knee: ["left_hip", "left_calf"],
  right_calf: ["right_knee", "right_foot"],
  left_calf: ["left_knee", "left_foot"],
  right_arm: ["right_shoulder"],
  left_arm: ["left_shoulder"],
  right_foot: ["right_calf"],
  left_foot: ["left_calf"],
};

// ---------------------------------------------------------------------------
// suggestGoal — Suggest a RecoveryGoal based on dominant signal type/severity
// ---------------------------------------------------------------------------

/**
 * Suggest a RecoveryGoal based on the dominant signal type and maximum severity.
 *
 * - stiffness / restriction → mobility
 * - soreness with severity ≥ 7 → relaxation
 * - tightness → warm_up
 * - guarding → relaxation
 * - default → recovery
 */
export function suggestGoal(
  signals: Array<{ type: string; severity: number }>,
): RecoveryGoal {
  if (signals.length === 0) return "recovery";

  const typeCounts: Record<string, number> = {};
  let maxSeverity = 0;
  for (const s of signals) {
    typeCounts[s.type] = (typeCounts[s.type] ?? 0) + 1;
    if (s.severity > maxSeverity) maxSeverity = s.severity;
  }

  const dominantType = Object.entries(typeCounts).sort(
    (a, b) => b[1] - a[1],
  )[0]?.[0];

  if (dominantType === "stiffness" || dominantType === "restriction") {
    return "mobility";
  }
  if (dominantType === "soreness" && maxSeverity >= 7) return "relaxation";
  if (dominantType === "tightness") return "warm_up";
  if (dominantType === "guarding") return "relaxation";
  return "recovery";
}

// ---------------------------------------------------------------------------
// findBilateralPartner — Find the bilateral partner for a given region
// ---------------------------------------------------------------------------

function findBilateralPartner(region: BodyRegion): BodyRegion | null {
  for (const [a, b] of BILATERAL_PAIRS) {
    if (region === a) return b;
    if (region === b) return a;
  }
  return null;
}

// ---------------------------------------------------------------------------
// scoreOutcome — Score a single session outcome for prior session summary
// ---------------------------------------------------------------------------

function scoreOutcome(outcome: Record<string, unknown>): number {
  let rating = 0;
  if (outcome.mobility_improved === "yes") rating += 0.3;
  if (outcome.session_effective === "yes") rating += 0.3;
  const sb = (outcome.stiffness_before as number) ?? 0;
  const sa = (outcome.stiffness_after as number) ?? 0;
  rating += (Math.max(0, sb - sa) / 10) * 0.2;
  if (outcome.repeat_intent === "yes") rating += 0.2;
  return Math.min(1.0, Math.max(0.0, rating));
}

// ---------------------------------------------------------------------------
// generateRecoveryMap — Main entry point
// ---------------------------------------------------------------------------

/**
 * Generate a Recovery Map from assessment data, client profile, and session
 * history. Stores the result in the assessment record's recovery_map JSONB field.
 *
 * Steps:
 * 1. Extract highlighted regions from assessment body_zones and recovery_signals
 * 2. For each region, compute ROM delta vs previous assessment
 * 3. Flag regions with ROM decrease > 5° as declining trend
 * 4. Flag regions where bilateral asymmetry > 10%
 * 5. Add compensation hints for adjacent regions with high asymmetry
 * 6. Attach wearable context from client_profile (if available)
 * 7. Fetch last 3 session summaries with outcome ratings
 * 8. Suggest a RecoveryGoal based on dominant signal type and severity
 * 9. Store the generated RecoveryMap in the assessment record
 */
export async function generateRecoveryMap(
  clientId: string,
  assessmentId: string,
  supabase: SupabaseClient,
): Promise<RecoveryMap> {
  // Fetch assessment
  const { data: assessment } = await supabase
    .from("assessments")
    .select("*")
    .eq("id", assessmentId)
    .maybeSingle();

  // Fetch client profile
  const { data: clientProfile } = await supabase
    .from("client_profiles")
    .select("*")
    .eq("id", clientId)
    .maybeSingle();

  // Fetch previous assessment for ROM delta comparison
  const { data: prevAssessments } = await supabase
    .from("assessments")
    .select("rom_values, asymmetry_scores")
    .eq("client_id", clientId)
    .lt("created_at", assessment?.created_at ?? new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1);

  const prevAssessment = prevAssessments?.[0] ?? null;

  // Fetch last 3 completed sessions with outcomes
  const { data: recentSessions } = await supabase
    .from("sessions")
    .select(`
      id, completed_at, session_config,
      outcomes (stiffness_before, stiffness_after, mobility_improved, session_effective, repeat_intent)
    `)
    .eq("client_id", clientId)
    .eq("status", "completed")
    .order("completed_at", { ascending: false })
    .limit(3);

  // Extract data from fetched records
  const recoverySignals =
    (clientProfile?.recovery_signals as Record<
      string,
      { type: string; severity: number }
    >) ?? {};
  const primaryRegions =
    (clientProfile?.primary_regions as BodyRegion[]) ?? [];
  const romValues =
    (assessment?.rom_values as Record<string, number>) ?? {};
  const prevRomValues =
    (prevAssessment?.rom_values as Record<string, number>) ?? {};
  const asymmetryScores =
    (assessment?.asymmetry_scores as Record<string, number>) ?? {};

  // Build signal list from recovery_signals
  const signals: Array<{
    region: BodyRegion;
    type: string;
    severity: number;
  }> = [];
  for (const [region, signal] of Object.entries(recoverySignals)) {
    if (signal && typeof signal === "object") {
      signals.push({
        region: region as BodyRegion,
        type: signal.type,
        severity: signal.severity,
      });
    }
  }

  // Include primary regions that don't already have signals
  for (const region of primaryRegions) {
    if (!signals.find((s) => s.region === region)) {
      signals.push({ region, type: "general", severity: 3 });
    }
  }

  // Build highlighted regions
  const highlightedRegions: HighlightedRegion[] = signals.map((signal) => {
    // Compute ROM delta vs previous assessment
    let romDelta: number | null = null;
    let trend: HighlightedRegion["trend"] = null;

    const regionRomKeys = Object.keys(romValues).filter((k) =>
      k.includes(signal.region),
    );
    if (regionRomKeys.length > 0) {
      const key = regionRomKeys[0];
      const currentRom = romValues[key];
      const prevRom = prevRomValues[key];
      if (currentRom !== undefined && prevRom !== undefined) {
        romDelta = currentRom - prevRom;
        if (romDelta < -5) trend = "declining";
        else if (romDelta > 5) trend = "improving";
        else trend = "stable";
      }
    }

    // Check bilateral asymmetry > 10%
    let asymmetryFlag = false;
    const partner = findBilateralPartner(signal.region);
    if (partner) {
      const asymmetry =
        asymmetryScores[signal.region] ?? asymmetryScores[partner];
      if (asymmetry !== undefined && asymmetry > 10) {
        asymmetryFlag = true;
      }
    }

    // Compensation hint from adjacent regions with high asymmetry
    let compensationHint: string | null = null;
    const adjacent = ADJACENT_REGIONS[signal.region] ?? [];
    for (const adj of adjacent) {
      const adjAsymmetry = asymmetryScores[adj];
      if (adjAsymmetry !== undefined && adjAsymmetry > 10) {
        compensationHint = `Likely compensating from ${adj.replace(/_/g, " ")}`;
        break;
      }
    }

    return {
      region: signal.region,
      severity: signal.severity,
      signalType: signal.type,
      romDelta,
      trend,
      asymmetryFlag,
      compensationHint,
    };
  });

  // Wearable context from client profile
  let wearableContext: WearableContext | null = null;
  if (clientProfile?.wearable_hrv != null) {
    wearableContext = {
      hrv: clientProfile.wearable_hrv as number,
      strain: (clientProfile.wearable_strain as number) ?? 0,
      sleepScore: (clientProfile.wearable_sleep_score as number) ?? 0,
      lastSync: (clientProfile.wearable_last_sync as string) ?? "",
    };
  }

  // Prior session summaries with outcome ratings
  const priorSessions: PriorSessionSummary[] = (recentSessions ?? []).map(
    (s) => {
      const config = s.session_config as Record<string, unknown>;
      const outcomes =
        (s.outcomes as Array<Record<string, unknown>>) ?? [];
      const outcome = outcomes[0];
      const outcomeRating = outcome ? scoreOutcome(outcome) : 0;

      return {
        date: (s.completed_at as string) ?? "",
        configSummary: `${config?.recoveryGoal ?? "recovery"}, ${Math.round(((config?.totalDuration as number) ?? 0) / 60)}min`,
        outcomeRating,
      };
    },
  );

  // Suggest goal based on dominant signal type and severity
  const suggestedGoal = suggestGoal(signals);

  const recoveryMap: RecoveryMap = {
    clientId,
    highlightedRegions,
    wearableContext,
    priorSessions,
    suggestedGoal,
    generatedAt: new Date().toISOString(),
  };

  // Store in assessment record's recovery_map JSONB field
  await supabase
    .from("assessments")
    .update({ recovery_map: recoveryMap })
    .eq("id", assessmentId);

  return recoveryMap;
}
