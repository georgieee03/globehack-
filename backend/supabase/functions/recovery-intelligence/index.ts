/**
 * Recovery Intelligence Edge Function — Action Router
 *
 * Single Edge Function handling all Recovery Intelligence Engine operations
 * via action-based routing: recommend, recovery-map, recovery-score, recovery-graph.
 *
 * Requirements: 23.1, 23.2, 23.3, 23.4, 23.5
 */

import { handleCors, jsonResponse, errorResponse, methodNotAllowed } from "../_shared/cors.ts";
import { requireAuthenticatedUser, requireRole, HttpError, createServiceRoleClient } from "../_shared/supabase-client.ts";
import type { BodyRegion } from "../_shared/safe-envelope.ts";
import { selectPrimaryRegion, mapBodyRegionToPadPlacement, mapGoalToModalityMix, type RecoveryGoal } from "./rules-engine.ts";
import { scoreHistory } from "./history-scorer.ts";
import { buildConfig } from "./config-builder.ts";
import { generateRecoveryMap } from "./recovery-map.ts";
import { queryRecoveryGraph, recomputeAndInsertRecoveryScore } from "./recovery-graph.ts";
import { buildPrompt, type LlmExplanationRequest } from "../llm-explanation/prompt-builder.ts";
import { generateFallbackExplanation } from "../llm-explanation/fallback-template.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ActionRequest {
  action: string;
  client_id?: string;
  assessment_id?: string;
  body_region?: BodyRegion;
  limit?: number;
}

async function resolveClientProfileIdForUser(
  supabase: ReturnType<typeof createServiceRoleClient>,
  userId: string,
  clinicId: string,
) {
  const { data: clientProfile, error } = await supabase
    .from("client_profiles")
    .select("id")
    .eq("user_id", userId)
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load client profile for authenticated user", {
      detail: error.message,
    });
  }

  if (!clientProfile?.id) {
    throw new HttpError(403, "This client account does not have a client profile in the current clinic");
  }

  return clientProfile.id as string;
}

// ---------------------------------------------------------------------------
// LLM Explanation helper (inline call with 3s timeout + fallback)
// ---------------------------------------------------------------------------

async function callLlmExplanation(
  input: LlmExplanationRequest,
): Promise<{ explanation: string; isFallback: boolean }> {
  const llmApiKey = Deno.env.get("LLM_API_KEY")?.trim();
  if (!llmApiKey) {
    return { explanation: generateFallbackExplanation(input), isFallback: true };
  }

  const prompt = buildPrompt(input);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 3000);

  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": llmApiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 256,
        messages: [{ role: "user", content: prompt }],
      }),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!response.ok) {
      return { explanation: generateFallbackExplanation(input), isFallback: true };
    }

    const result = await response.json();
    const text = result?.content?.[0]?.text;
    return text
      ? { explanation: text, isFallback: false }
      : { explanation: generateFallbackExplanation(input), isFallback: true };
  } catch {
    clearTimeout(timeout);
    return { explanation: generateFallbackExplanation(input), isFallback: true };
  }
}


// ---------------------------------------------------------------------------
// handleRecommend — Full recommendation pipeline
// ---------------------------------------------------------------------------

async function handleRecommend(
  supabase: ReturnType<typeof createServiceRoleClient>,
  clinicId: string,
  clientId: string,
  assessmentId: string,
) {
  // Fetch assessment scoped to clinic
  const { data: assessment, error: assessError } = await supabase
    .from("assessments")
    .select("*")
    .eq("id", assessmentId)
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (assessError || !assessment) {
    throw new HttpError(404, "Assessment not found");
  }

  // Fetch client profile scoped to clinic
  const { data: profile, error: profileError } = await supabase
    .from("client_profiles")
    .select("*")
    .eq("id", clientId)
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (profileError || !profile) {
    throw new HttpError(404, "Client profile not found");
  }

  // Extract data from records
  const recoverySignals =
    (profile.recovery_signals as Record<string, { type: string; severity: number }>) ?? {};
  const primaryRegions = (profile.primary_regions as BodyRegion[]) ?? [];
  const romValues = (assessment.rom_values as Record<string, number>) ?? {};
  const asymmetryScores = (assessment.asymmetry_scores as Record<string, number>) ?? {};
  const recoveryGoal = (assessment.recovery_goal as RecoveryGoal) ?? "recovery";
  const sensitivities = (profile.sensitivities as string[]) ?? [];

  // Build highlighted regions for primary region selection
  const signals: Array<{ region: BodyRegion; severity: number }> = [];
  for (const [region, signal] of Object.entries(recoverySignals)) {
    if (signal && typeof signal === "object") {
      signals.push({ region: region as BodyRegion, severity: signal.severity });
    }
  }
  for (const region of primaryRegions) {
    if (!signals.find((s) => s.region === region)) {
      signals.push({ region, severity: 3 });
    }
  }

  // Rules Engine: select primary region
  const primaryRegion =
    signals.length > 0
      ? selectPrimaryRegion(signals)
      : (primaryRegions[0] ?? ("lower_back" as BodyRegion));

  // Rules Engine: pad placement with compensation hints
  const padPlacement = mapBodyRegionToPadPlacement(
    primaryRegion,
    asymmetryScores,
    Object.entries(recoverySignals).map(([region, signal]) => ({
      region: region as BodyRegion,
      type: (signal as { type: string }).type,
      severity: (signal as { severity: number }).severity,
    })),
  );

  // Rules Engine: modality mix from goal
  const modalityMix = mapGoalToModalityMix(recoveryGoal);

  // History Scorer
  const historyResult = await scoreHistory(clientId, supabase);

  // Wearable context from client profile
  const wearableContext =
    profile.wearable_hrv != null
      ? {
          hrv: profile.wearable_hrv as number,
          strain: (profile.wearable_strain as number) ?? 0,
          sleepScore: (profile.wearable_sleep_score as number) ?? 0,
        }
      : undefined;

  // Config Builder: full pipeline
  const { sessionConfig, clampingLog } = buildConfig({
    padPlacement,
    modalityMix,
    historyResult,
    sensitivities,
    wearableContext,
    bodyRegion: primaryRegion,
    mac: "", // Placeholder — set during device selection
  });

  // Recovery Map
  const recoveryMap = await generateRecoveryMap(clientId, assessmentId, supabase);

  // Recovery Score (recompute and insert)
  const recoveryScore = await recomputeAndInsertRecoveryScore(supabase, clinicId, clientId);

  // LLM Explanation
  const llmInput: LlmExplanationRequest = {
    targetRegion: primaryRegion,
    recoveryGoal,
    romValues,
    asymmetryScores,
    priorSessionCount: historyResult.sessionScores.length,
    bestPriorOutcomeScore: historyResult.sessionScores.reduce(
      (max, s) => Math.max(max, s.score),
      0,
    ),
    confidencePercent: historyResult.confidence * 100,
    sessionDuration: sessionConfig.totalDuration,
    thermalPwmHot: sessionConfig.pwmValues.hot,
    thermalPwmCold: sessionConfig.pwmValues.cold,
    vibMin: sessionConfig.vibMin,
    vibMax: sessionConfig.vibMax,
    ledStatus: sessionConfig.led,
    clientName: (profile.notes as string) ?? "Client",
    targetRegions: primaryRegions.length > 0 ? primaryRegions : [primaryRegion],
    wearableContext,
  };
  const { explanation } = await callLlmExplanation(llmInput);

  return {
    sessionConfig,
    recoveryMap,
    recoveryScore,
    confidence: historyResult.confidence,
    explanation,
    adjustments: historyResult.adjustments,
    clampingLog,
  };
}


// ---------------------------------------------------------------------------
// Edge Function entry point — Deno.serve with action-based routing
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Only POST allowed
  if (req.method !== "POST") return methodNotAllowed(req);

  const supabase = createServiceRoleClient();

  try {
    // Authenticate and authorize
    const ctx = await requireAuthenticatedUser(req, supabase);

    // Parse request body
    const body: ActionRequest = await req.json().catch(() => {
      throw new HttpError(400, "Request body must be valid JSON");
    });

    const { action, assessment_id, body_region, limit } = body;
    let effectiveClientId = body.client_id;

    if (action === "recommend") {
      requireRole(ctx, ["admin", "practitioner"]);
    } else if (["recovery-map", "recovery-score", "recovery-graph"].includes(action)) {
      if (ctx.role === "client") {
        const ownClientProfileId = await resolveClientProfileIdForUser(
          supabase,
          ctx.user.id,
          ctx.clinicId,
        );

        if (effectiveClientId && effectiveClientId !== ownClientProfileId) {
          throw new HttpError(403, "Clients can only access their own recovery data");
        }

        effectiveClientId = ownClientProfileId;
      } else {
        requireRole(ctx, ["admin", "practitioner"]);
      }
    }

    switch (action) {
      case "recommend": {
        if (!effectiveClientId || !assessment_id) {
          throw new HttpError(
            400,
            "client_id and assessment_id are required for recommend action",
          );
        }
        const result = await handleRecommend(
          supabase,
          ctx.clinicId,
          effectiveClientId,
          assessment_id,
        );
        return jsonResponse(req, { success: true, action, data: result });
      }

      case "recovery-map": {
        if (!effectiveClientId || !assessment_id) {
          throw new HttpError(
            400,
            "client_id and assessment_id are required for recovery-map action",
          );
        }
        const recoveryMap = await generateRecoveryMap(
          effectiveClientId,
          assessment_id,
          supabase,
        );
        return jsonResponse(req, {
          success: true,
          action,
          data: { recoveryMap },
        });
      }

      case "recovery-score": {
        if (!effectiveClientId) {
          throw new HttpError(
            400,
            "client_id is required for recovery-score action",
          );
        }
        const score = await recomputeAndInsertRecoveryScore(
          supabase,
          ctx.clinicId,
          effectiveClientId,
        );
        return jsonResponse(req, {
          success: true,
          action,
          data: { score, computedAt: new Date().toISOString() },
        });
      }

      case "recovery-graph": {
        if (!effectiveClientId || !body_region) {
          throw new HttpError(
            400,
            "client_id and body_region are required for recovery-graph action",
          );
        }
        const dataPoints = await queryRecoveryGraph(
          supabase,
          effectiveClientId,
          body_region,
          limit ?? 30,
        );
        return jsonResponse(req, {
          success: true,
          action,
          data: { dataPoints },
        });
      }

      default:
        return errorResponse(req, 400, "Invalid action", {
          allowed: ["recommend", "recovery-map", "recovery-score", "recovery-graph"],
        });
    }
  } catch (err) {
    if (err instanceof HttpError) {
      return errorResponse(req, err.status, err.message, err.details);
    }
    console.error("recovery-intelligence unexpected error:", err);
    return errorResponse(req, 500, "Internal server error");
  }
});
