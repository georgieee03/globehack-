import {
  handleCors,
  jsonResponse,
  errorResponse,
  methodNotAllowed,
} from "../_shared/cors.ts";
import {
  requireAuthenticatedUser,
  HttpError,
  type AuthenticatedUserContext,
} from "../_shared/supabase-client.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

// ─── Types ───────────────────────────────────────────────────────────────────

interface OutcomeRequest {
  session_id: string;
  recorded_by: "client" | "practitioner";
  stiffness_before?: number;
  stiffness_after: number;
  soreness_after?: number;
  mobility_improved: boolean | null;
  session_effective: boolean | null;
  repeat_intent: "yes" | "maybe" | "no";
  rom_after?: Record<string, number>;
  notes?: string;
}

interface NextVisitSignal {
  recommended_return_days: number;
  urgency: "routine" | "soon" | "priority";
  rationale: string;
}

type TrendClassification = "improving" | "plateau" | "regressing" | "insufficient_data";

// ─── Validation ──────────────────────────────────────────────────────────────

function validateOutcomeRequest(body: OutcomeRequest): string[] {
  const errors: string[] = [];

  if (!body.session_id) {
    errors.push("session_id is required");
  }

  if (!body.recorded_by || !["client", "practitioner"].includes(body.recorded_by)) {
    errors.push("recorded_by must be 'client' or 'practitioner'");
  }

  if (body.stiffness_after == null) {
    errors.push("stiffness_after is required");
  } else if (!Number.isInteger(body.stiffness_after) || body.stiffness_after < 0 || body.stiffness_after > 10) {
    errors.push("stiffness_after must be an integer between 0 and 10");
  }

  if (body.stiffness_before != null) {
    if (!Number.isInteger(body.stiffness_before) || body.stiffness_before < 0 || body.stiffness_before > 10) {
      errors.push("stiffness_before must be an integer between 0 and 10");
    }
  }

  if (body.soreness_after != null) {
    if (!Number.isInteger(body.soreness_after) || body.soreness_after < 0 || body.soreness_after > 10) {
      errors.push("soreness_after must be an integer between 0 and 10");
    }
  }

  if (!body.repeat_intent || !["yes", "maybe", "no"].includes(body.repeat_intent)) {
    errors.push("repeat_intent must be 'yes', 'maybe', or 'no'");
  }

  if (body.rom_after != null && typeof body.rom_after !== "object") {
    errors.push("rom_after must be an object mapping joint names to numeric values");
  }

  return errors;
}

// ─── Recovery Score Computation ──────────────────────────────────────────────

async function computeRecoveryScore(
  supabase: SupabaseClient,
  clientId: string,
  sessionId: string,
): Promise<number> {
  let score = 50; // baseline

  // Outcome trend component (±20 points)
  const { data: recentOutcomes } = await supabase
    .from("outcomes")
    .select("stiffness_before, stiffness_after")
    .eq("client_id", clientId)
    .not("stiffness_after", "is", null)
    .order("created_at", { ascending: false })
    .limit(5);

  if (recentOutcomes && recentOutcomes.length >= 2) {
    const reductions = recentOutcomes
      .filter((o: Record<string, unknown>) => o.stiffness_before != null && o.stiffness_after != null)
      .map((o: Record<string, unknown>) => ((o.stiffness_before as number) - (o.stiffness_after as number)) / 10);

    if (reductions.length > 0) {
      const avgReduction = reductions.reduce((a: number, b: number) => a + b, 0) / reductions.length;
      score += Math.round(avgReduction * 40); // scale to ±20
    }
  }

  // Check-in trend component (±10 points)
  const { data: recentCheckins } = await supabase
    .from("daily_checkins")
    .select("overall_feeling")
    .eq("client_id", clientId)
    .order("created_at", { ascending: false })
    .limit(7);

  if (recentCheckins && recentCheckins.length > 0) {
    const avgFeeling = recentCheckins.reduce(
      (sum: number, c: Record<string, unknown>) => sum + (c.overall_feeling as number), 0
    ) / recentCheckins.length;
    // Scale 1-5 feeling to -10 to +10
    score += Math.round((avgFeeling - 3) * 5);
  }

  // Wearable context component (±10 points)
  const { data: clientProfile } = await supabase
    .from("client_profiles")
    .select("wearable_hrv, wearable_sleep_score")
    .eq("id", clientId)
    .maybeSingle();

  if (clientProfile) {
    if (clientProfile.wearable_sleep_score != null) {
      // Sleep score 0-100, map to -5 to +5
      score += Math.round((clientProfile.wearable_sleep_score - 50) / 10);
    }
    if (clientProfile.wearable_hrv != null) {
      // HRV: higher is better, rough mapping
      const hrvBonus = Math.min(5, Math.max(-5, Math.round((clientProfile.wearable_hrv - 50) / 10)));
      score += hrvBonus;
    }
  }

  // Session adherence component (+10 points max)
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const { count: sessionCount } = await supabase
    .from("sessions")
    .select("id", { count: "exact", head: true })
    .eq("client_id", clientId)
    .eq("status", "completed")
    .gte("created_at", thirtyDaysAgo);

  if (sessionCount != null && sessionCount > 0) {
    // 4+ sessions in 30 days = full +10 bonus
    score += Math.min(10, Math.round(sessionCount * 2.5));
  }

  // Clamp to 0-100
  return Math.max(0, Math.min(100, score));
}

// ─── Trend Analysis ──────────────────────────────────────────────────────────

function computeTrend(
  recentOutcomes: Array<{ stiffness_after: number | null }>
): TrendClassification {
  const stiffnessValues = recentOutcomes
    .filter((o) => o.stiffness_after != null)
    .map((o) => o.stiffness_after!);

  if (stiffnessValues.length < 3) return "insufficient_data";

  // Values are ordered newest first: [latest, mid, oldest]
  const [latest, _mid, oldest] = stiffnessValues;
  const totalChange = oldest - latest;
  const absChange = Math.abs(totalChange);

  if (absChange <= 1) return "plateau";
  if (totalChange > 0) return "improving"; // stiffness decreased
  return "regressing"; // stiffness increased
}

function computeNextVisitSignal(
  recoveryScore: number,
  trend: TrendClassification,
): NextVisitSignal {
  if (recoveryScore < 40 && trend === "regressing") {
    return {
      recommended_return_days: 2,
      urgency: "priority",
      rationale:
        "Recovery Score below 40 with regressing trend — early return recommended.",
    };
  }

  if (recoveryScore <= 70 && trend === "plateau") {
    return {
      recommended_return_days: 4,
      urgency: "soon",
      rationale:
        "Recovery Score plateauing — a follow-up session may help break through.",
    };
  }

  return {
    recommended_return_days: 10,
    urgency: "routine",
    rationale:
      "Recovery trajectory is positive — routine follow-up recommended.",
  };
}

// ─── Recovery Graph Updates ──────────────────────────────────────────────────

async function insertRecoveryGraphPoints(
  supabase: SupabaseClient,
  clientId: string,
  sessionId: string,
  bodyRegion: string,
  outcome: OutcomeRequest,
): Promise<void> {
  const points: Array<{
    client_id: string;
    body_region: string;
    metric_type: string;
    value: number;
    source: string;
    source_id: string;
  }> = [];

  // Stiffness point
  if (outcome.stiffness_after != null) {
    points.push({
      client_id: clientId,
      body_region: bodyRegion,
      metric_type: "stiffness",
      value: outcome.stiffness_after,
      source: "session_outcome",
      source_id: sessionId,
    });
  }

  // Soreness point
  if (outcome.soreness_after != null) {
    points.push({
      client_id: clientId,
      body_region: bodyRegion,
      metric_type: "soreness",
      value: outcome.soreness_after,
      source: "session_outcome",
      source_id: sessionId,
    });
  }

  // ROM points
  if (outcome.rom_after) {
    for (const [jointName, value] of Object.entries(outcome.rom_after)) {
      if (typeof value === "number") {
        points.push({
          client_id: clientId,
          body_region: bodyRegion,
          metric_type: `rom_${jointName}`,
          value,
          source: "session_outcome",
          source_id: sessionId,
        });
      }
    }
  }

  if (points.length > 0) {
    const { error } = await supabase.from("recovery_graph").insert(points);
    if (error) {
      console.error("Failed to insert recovery graph points:", error);
      throw new HttpError(500, "Failed to update Recovery Graph", {
        detail: error.message,
      });
    }
  }
}

// ─── Main Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  // Only accept POST
  if (req.method !== "POST") {
    return methodNotAllowed(req);
  }

  try {
    // Authenticate
    const ctx: AuthenticatedUserContext = await requireAuthenticatedUser(req);
    const supabase = ctx.supabase;

    // Parse body
    const body: OutcomeRequest = await req.json();

    // Validate
    const validationErrors = validateOutcomeRequest(body);
    if (validationErrors.length > 0) {
      return errorResponse(req, 400, "Validation failed", {
        errors: validationErrors,
      });
    }

    // Verify session exists and has session_config
    const { data: session, error: sessionError } = await supabase
      .from("sessions")
      .select("id, client_id, clinic_id, session_config, assessment_id")
      .eq("id", body.session_id)
      .maybeSingle();

    if (sessionError || !session) {
      return errorResponse(req, 404, "Session not found", {
        session_id: body.session_id,
      });
    }

    if (!session.session_config) {
      return errorResponse(req, 400, "Session does not have a session_config", {
        session_id: body.session_id,
      });
    }

    // Check for duplicate client outcome
    if (body.recorded_by === "client") {
      const { data: existing } = await supabase
        .from("outcomes")
        .select("id")
        .eq("session_id", body.session_id)
        .eq("recorded_by", "client")
        .maybeSingle();

      if (existing) {
        return errorResponse(
          req,
          409,
          "A client outcome has already been recorded for this session",
          { session_id: body.session_id },
        );
      }
    }

    // Compute ROM delta if rom_after provided and assessment exists
    let romDelta: Record<string, number> | null = null;
    if (body.rom_after && session.assessment_id) {
      const { data: assessment } = await supabase
        .from("assessments")
        .select("rom_data")
        .eq("id", session.assessment_id)
        .maybeSingle();

      if (assessment?.rom_data && typeof assessment.rom_data === "object") {
        romDelta = {};
        for (const [key, afterVal] of Object.entries(body.rom_after)) {
          const beforeVal = (assessment.rom_data as Record<string, number>)[key];
          if (typeof beforeVal === "number" && typeof afterVal === "number") {
            romDelta[key] = afterVal - beforeVal;
          }
        }
      }
    }

    // Insert outcome
    const outcomeRecord = {
      session_id: body.session_id,
      client_id: session.client_id,
      clinic_id: session.clinic_id,
      recorded_by: body.recorded_by,
      recorded_by_user_id: ctx.user.id,
      stiffness_before: body.stiffness_before ?? null,
      stiffness_after: body.stiffness_after,
      soreness_after: body.soreness_after ?? null,
      mobility_improved: body.mobility_improved == null
        ? null
        : body.mobility_improved
          ? "yes"
          : "no",
      session_effective: body.session_effective == null
        ? null
        : body.session_effective
          ? "yes"
          : "no",
      repeat_intent: body.repeat_intent,
      rom_after: body.rom_after ?? null,
      rom_delta: romDelta,
      client_notes: body.recorded_by === "client" ? (body.notes ?? null) : null,
      practitioner_notes:
        body.recorded_by === "practitioner" ? (body.notes ?? null) : null,
    };

    const { data: insertedOutcome, error: insertError } = await supabase
      .from("outcomes")
      .insert(outcomeRecord)
      .select("id")
      .single();

    if (insertError) {
      console.error("Failed to insert outcome:", insertError);
      // Check for unique constraint violation (duplicate)
      if (insertError.code === "23505") {
        return errorResponse(
          req,
          409,
          "An outcome has already been recorded for this session by this role",
          { session_id: body.session_id },
        );
      }
      return errorResponse(req, 500, "Failed to record outcome", {
        detail: insertError.message,
      });
    }

    // Extract body region from session config
    const bodyRegion: string =
      (session.session_config as Record<string, unknown>)?.bodyRegion as string ||
      "overall";

    // Insert Recovery Graph points
    await insertRecoveryGraphPoints(
      supabase,
      session.client_id,
      body.session_id,
      bodyRegion,
      body,
    );

    // Recompute Recovery Score
    const recoveryScore = await computeRecoveryScore(
      supabase,
      session.client_id,
      body.session_id,
    );

    // Insert Recovery Score into graph
    const { error: scoreInsertError } = await supabase
      .from("recovery_graph")
      .insert({
        client_id: session.client_id,
        body_region: "overall",
        metric_type: "recovery_score",
        value: recoveryScore,
        source: "session_outcome",
        source_id: body.session_id,
      });

    if (scoreInsertError) {
      console.error("Failed to insert recovery score:", scoreInsertError);
    }

    // Compute trend from last 3 outcomes
    const { data: trendOutcomes } = await supabase
      .from("outcomes")
      .select("stiffness_after")
      .eq("client_id", session.client_id)
      .not("stiffness_after", "is", null)
      .order("created_at", { ascending: false })
      .limit(3);

    const trend = computeTrend(trendOutcomes ?? []);

    // Compute next-visit signal
    const nextVisitSignal = computeNextVisitSignal(recoveryScore, trend);

    // Update client profile with trend data
    const { error: profileUpdateError } = await supabase
      .from("client_profiles")
      .update({
        trend_classification: trend,
        needs_attention: trend === "plateau",
        next_visit_signal: nextVisitSignal,
      })
      .eq("id", session.client_id);

    if (profileUpdateError) {
      console.error("Failed to update client profile trend:", profileUpdateError);
    }

    return jsonResponse(req, {
      success: true,
      outcomeId: insertedOutcome.id,
      recoveryScore,
      trend,
      nextVisitSignal,
    });
  } catch (err) {
    if (err instanceof HttpError) {
      return errorResponse(req, err.status, err.message, err.details);
    }
    console.error("Unexpected error in outcome-recorder:", err);
    return errorResponse(req, 500, "Internal server error");
  }
});
