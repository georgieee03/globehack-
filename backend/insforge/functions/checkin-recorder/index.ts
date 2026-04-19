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
  insertCheckinGraphPoints,
  recomputeAndInsertRecoveryScore,
} from "../recovery-intelligence/recovery-graph.ts";
import {
  normalizeCheckinRequest,
  toStoredTargetRegions,
} from "./logic.ts";

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return methodNotAllowed(req);
  }

  try {
    const ctx = await requireAuthenticatedUser(req);
    requireRole(ctx, "client");

    const payload = await req.json();
    const { value: body, errors } = normalizeCheckinRequest(payload);

    if (!body || errors.length > 0) {
      return errorResponse(req, 400, "Validation failed", { errors });
    }

    const { data: clientProfile, error: clientProfileError } = await ctx.insforge
      .from("client_profiles")
      .select("id, clinic_id")
      .eq("user_id", ctx.user.id)
      .eq("clinic_id", ctx.clinicId)
      .maybeSingle();

    if (clientProfileError) {
      throw new HttpError(500, "Failed to load client profile", {
        detail: clientProfileError.message,
      });
    }

    if (!clientProfile) {
      throw new HttpError(404, "Client profile not found for this authenticated user");
    }

    const { data: insertedCheckin, error: insertError } = await ctx.insforge
      .from("daily_checkins")
      .insert({
        client_id: clientProfile.id,
        clinic_id: clientProfile.clinic_id,
        checkin_type: body.checkinType,
        overall_feeling: body.overallFeeling,
        target_regions: toStoredTargetRegions(body.targetRegions),
        activity_since_last: body.activitySinceLast,
      })
      .select("id")
      .single();

    if (insertError) {
      throw new HttpError(500, "Failed to record daily check-in", {
        detail: insertError.message,
      });
    }

    await insertCheckinGraphPoints(
      ctx.insforge,
      clientProfile.clinic_id as string,
      clientProfile.id as string,
      insertedCheckin.id as string,
      body.overallFeeling,
      body.targetRegions,
    );

    const recoveryScore = await recomputeAndInsertRecoveryScore(
      ctx.insforge,
      clientProfile.clinic_id as string,
      clientProfile.id as string,
    );

    const { error: updateError } = await ctx.insforge
      .from("daily_checkins")
      .update({ recovery_score: recoveryScore })
      .eq("id", insertedCheckin.id)
      .eq("client_id", clientProfile.id);

    if (updateError) {
      throw new HttpError(500, "Failed to persist computed recovery score", {
        detail: updateError.message,
      });
    }

    return jsonResponse(req, {
      success: true,
      checkinId: insertedCheckin.id,
      recoveryScore,
    });
  } catch (err) {
    if (err instanceof HttpError) {
      return errorResponse(req, err.status, err.message, err.details);
    }

    console.error("Unexpected error in checkin-recorder:", err);
    return errorResponse(req, 500, "Internal server error");
  }
});
