import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/cors.ts";
import {
  HttpError,
  requireAuthenticatedUser,
  requireRole,
} from "../_shared/insforge-client.ts";
import {
  insertRecoveryGraphPoints,
  recomputeAndInsertRecoveryScore,
} from "../recovery-intelligence/recovery-graph.ts";
import {
  buildOutcomeGraphMetrics,
  computeRomDelta,
  deriveOutcomeBodyRegion,
  normalizeOutcomeRequest,
} from "./logic.ts";

interface NextVisitSignal {
  recommended_return_days: number;
  urgency: "routine" | "soon" | "priority";
  rationale: string;
}

type TrendClassification =
  | "improving"
  | "plateau"
  | "regressing"
  | "insufficient_data";

interface SessionRecord {
  id: string;
  client_id: string;
  clinic_id: string;
  session_config: unknown;
  assessment_id: string | null;
  created_at?: string;
}

interface AssessmentRecord {
  id: string;
  rom_values: unknown;
  body_zones: unknown;
  recovery_map: unknown;
}

function computeTrend(
  recentOutcomes: Array<{ stiffness_after: number | null }>,
): TrendClassification {
  const stiffnessValues = recentOutcomes
    .filter((outcome) => outcome.stiffness_after != null)
    .map((outcome) => outcome.stiffness_after as number);

  if (stiffnessValues.length < 3) return "insufficient_data";

  const [latest, , oldest] = stiffnessValues;
  const totalChange = oldest - latest;
  const absChange = Math.abs(totalChange);

  if (absChange <= 1) return "plateau";
  if (totalChange > 0) return "improving";
  return "regressing";
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
        "Recovery Score below 40 with regressing trend Ã¢â‚¬â€ early return recommended.",
    };
  }

  if (recoveryScore <= 70 && trend === "plateau") {
    return {
      recommended_return_days: 4,
      urgency: "soon",
      rationale:
        "Recovery Score plateauing Ã¢â‚¬â€ a follow-up session may help break through.",
    };
  }

  return {
    recommended_return_days: 10,
    urgency: "routine",
    rationale:
      "Recovery trajectory is positive Ã¢â‚¬â€ routine follow-up recommended.",
  };
}

async function loadClientProfileIdForUser(
  userId: string,
  clinicId: string,
  insforge: Awaited<ReturnType<typeof requireAuthenticatedUser>>["insforge"],
): Promise<string> {
  const { data: clientProfile, error } = await insforge
    .from("client_profiles")
    .select("id")
    .eq("user_id", userId)
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load client profile", {
      detail: error.message,
    });
  }

  if (!clientProfile?.id) {
    throw new HttpError(
      403,
      "This client account does not have a client profile in the current clinic",
    );
  }

  return clientProfile.id as string;
}

async function resolveSessionForOutcome(
  sessionReference: string,
  clinicId: string,
  insforge: Awaited<ReturnType<typeof requireAuthenticatedUser>>["insforge"],
): Promise<SessionRecord | null> {
  const directResult = await insforge
    .from("sessions")
    .select("id, client_id, clinic_id, session_config, assessment_id, created_at")
    .eq("id", sessionReference)
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (directResult.error) {
    throw new HttpError(500, "Failed to load session", {
      detail: directResult.error.message,
    });
  }

  if (directResult.data) {
    return directResult.data as SessionRecord;
  }

  const fallbackResult = await insforge
    .from("sessions")
    .select("id, client_id, clinic_id, session_config, assessment_id, created_at")
    .eq("assessment_id", sessionReference)
    .eq("clinic_id", clinicId)
    .order("created_at", { ascending: false })
    .limit(1);

  if (fallbackResult.error) {
    throw new HttpError(500, "Failed to resolve session from assessment", {
      detail: fallbackResult.error.message,
    });
  }

  return ((fallbackResult.data ?? [])[0] as SessionRecord | undefined) ?? null;
}

async function loadAssessmentForSession(
  session: SessionRecord,
  insforge: Awaited<ReturnType<typeof requireAuthenticatedUser>>["insforge"],
): Promise<AssessmentRecord | null> {
  if (!session.assessment_id) {
    return null;
  }

  const { data, error } = await insforge
    .from("assessments")
    .select("id, rom_values, body_zones, recovery_map")
    .eq("id", session.assessment_id)
    .eq("client_id", session.client_id)
    .eq("clinic_id", session.clinic_id)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load linked assessment", {
      detail: error.message,
    });
  }

  return (data as AssessmentRecord | null) ?? null;
}

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return methodNotAllowed(req);
  }

  try {
    const ctx = await requireAuthenticatedUser(req);
    const payload = await req.json();
    const { value: body, errors } = normalizeOutcomeRequest(payload);

    if (!body || errors.length > 0) {
      return errorResponse(req, 400, "Validation failed", { errors });
    }

    if (body.recordedBy === "client") {
      requireRole(ctx, "client");
    } else {
      requireRole(ctx, ["practitioner", "admin"]);
    }

    const session = await resolveSessionForOutcome(
      body.sessionId,
      ctx.clinicId,
      ctx.insforge,
    );

    if (!session) {
      return errorResponse(req, 404, "Session not found", {
        session_id: body.sessionId,
      });
    }

    if (body.recordedBy === "client") {
      const clientProfileId = await loadClientProfileIdForUser(
        ctx.user.id,
        ctx.clinicId,
        ctx.insforge,
      );

      if (session.client_id !== clientProfileId) {
        return errorResponse(
          req,
          403,
          "Clients can only record outcomes for their own sessions",
        );
      }
    }

    if (!session.session_config) {
      return errorResponse(req, 400, "Session does not have a session_config", {
        session_id: session.id,
      });
    }

    if (body.recordedBy === "client") {
      const { data: existingOutcome, error: existingError } = await ctx.insforge
        .from("outcomes")
        .select("id")
        .eq("session_id", session.id)
        .eq("recorded_by", "client")
        .maybeSingle();

      if (existingError) {
        throw new HttpError(500, "Failed to check for duplicate client outcomes", {
          detail: existingError.message,
        });
      }

      if (existingOutcome) {
        return errorResponse(
          req,
          409,
          "A client outcome has already been recorded for this session",
          { session_id: session.id },
        );
      }
    }

    const assessment = await loadAssessmentForSession(session, ctx.insforge);
    const romDelta = computeRomDelta(body.romAfter, assessment?.rom_values);

    const outcomeRecord = {
      session_id: session.id,
      client_id: session.client_id,
      clinic_id: session.clinic_id,
      recorded_by: body.recordedBy,
      recorded_by_user_id: ctx.user.id,
      stiffness_before: body.stiffnessBefore,
      stiffness_after: body.stiffnessAfter,
      soreness_after: body.sorenessAfter,
      mobility_improved: body.mobilityImproved,
      session_effective: body.sessionEffective,
      readiness_improved: body.readinessImproved,
      repeat_intent: body.repeatIntent,
      rom_after: body.romAfter,
      rom_delta: romDelta,
      client_notes: body.recordedBy === "client" ? body.notes : null,
      practitioner_notes: body.recordedBy === "practitioner" ? body.notes : null,
    };

    const { data: insertedOutcome, error: insertError } = await ctx.insforge
      .from("outcomes")
      .insert(outcomeRecord)
      .select("id")
      .single();

    if (insertError) {
      if (insertError.code === "23505") {
        return errorResponse(
          req,
          409,
          "An outcome has already been recorded for this session by this role",
          { session_id: session.id },
        );
      }

      throw new HttpError(500, "Failed to record outcome", {
        detail: insertError.message,
      });
    }

    const bodyRegion = deriveOutcomeBodyRegion({
      sessionConfig: session.session_config,
      assessment,
    });
    const metrics = buildOutcomeGraphMetrics(body);

    await insertRecoveryGraphPoints(
      ctx.insforge,
      session.clinic_id,
      session.client_id,
      session.id,
      bodyRegion,
      metrics,
    );

    const recoveryScore = await recomputeAndInsertRecoveryScore(
      ctx.insforge,
      session.clinic_id,
      session.client_id,
    );

    const { data: trendOutcomes, error: trendError } = await ctx.insforge
      .from("outcomes")
      .select("stiffness_after")
      .eq("client_id", session.client_id)
      .eq("clinic_id", session.clinic_id)
      .not("stiffness_after", "is", null)
      .order("created_at", { ascending: false })
      .limit(3);

    if (trendError) {
      throw new HttpError(500, "Failed to compute trend classification", {
        detail: trendError.message,
      });
    }

    const trend = computeTrend(
      (trendOutcomes ?? []) as Array<{ stiffness_after: number | null }>,
    );
    const nextVisitSignal = computeNextVisitSignal(recoveryScore, trend);

    const { error: profileUpdateError } = await ctx.insforge
      .from("client_profiles")
      .update({
        trend_classification: trend,
        needs_attention: trend === "plateau",
        next_visit_signal: nextVisitSignal,
      })
      .eq("id", session.client_id)
      .eq("clinic_id", session.clinic_id);

    if (profileUpdateError) {
      throw new HttpError(500, "Failed to update client recovery trend", {
        detail: profileUpdateError.message,
      });
    }

    return jsonResponse(req, {
      success: true,
      outcomeId: insertedOutcome.id,
      sessionId: session.id,
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
