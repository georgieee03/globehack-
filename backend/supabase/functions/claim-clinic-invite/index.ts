import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/cors.ts";
import {
  createServiceRoleClient,
  extractBearerToken,
  HttpError,
} from "../_shared/supabase-client.ts";
import { normalizeClaimClinicInviteRequest } from "./logic.ts";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function rollbackInviteClaim(
  inviteId: string,
  claimedBy: string,
): Promise<void> {
  const supabase = createServiceRoleClient();
  const { error } = await supabase
    .from("clinic_invites")
    .update({
      claimed_by: null,
      claimed_at: null,
    })
    .eq("id", inviteId)
    .eq("claimed_by", claimedBy);

  if (error) {
    console.error("Failed to roll back clinic invite claim:", error);
  }
}

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return methodNotAllowed(req);
  }

  try {
    const supabase = createServiceRoleClient();
    const token = extractBearerToken(req);
    const { data, error: authError } = await supabase.auth.getUser(token);

    if (authError || !data.user) {
      throw new HttpError(401, "Invalid or expired Supabase session", {
        detail: authError?.message,
      });
    }

    const authUser = data.user;
    const payload = await req.json();
    const { value: body, errors } = normalizeClaimClinicInviteRequest(payload);

    if (!body || errors.length > 0) {
      return errorResponse(req, 400, "Validation failed", { errors });
    }

    const { data: existingUser, error: existingUserError } = await supabase
      .from("users")
      .select("id, clinic_id, role")
      .eq("id", authUser.id)
      .maybeSingle();

    if (existingUserError) {
      throw new HttpError(500, "Failed to check current onboarding state", {
        detail: existingUserError.message,
      });
    }

    if (existingUser) {
      return errorResponse(
        req,
        409,
        "This authenticated user is already assigned to a clinic",
        {
          clinic_id: existingUser.clinic_id,
          role: existingUser.role,
        },
      );
    }

    const { data: invite, error: inviteError } = await supabase
      .from("clinic_invites")
      .select("id, clinic_id, role, email, claimed_at, expires_at")
      .eq("invite_code", body.inviteCode)
      .maybeSingle();

    if (inviteError) {
      throw new HttpError(500, "Failed to validate invite code", {
        detail: inviteError.message,
      });
    }

    if (!invite) {
      return errorResponse(req, 404, "Invite code not found", {
        invite_code: body.inviteCode,
      });
    }

    if (invite.role !== "client") {
      return errorResponse(req, 403, "Invite code is not valid for client onboarding", {
        invite_code: body.inviteCode,
      });
    }

    if (invite.claimed_at) {
      return errorResponse(req, 409, "Invite code has already been claimed", {
        invite_code: body.inviteCode,
      });
    }

    if (
      invite.expires_at &&
      new Date(invite.expires_at as string).getTime() <= Date.now()
    ) {
      return errorResponse(req, 410, "Invite code has expired", {
        invite_code: body.inviteCode,
      });
    }

    const authEmail = authUser.email?.trim() ?? "";
    const inviteEmail = typeof invite.email === "string"
      ? invite.email.trim().toLowerCase()
      : null;

    if (inviteEmail && authEmail.toLowerCase() !== inviteEmail) {
      return errorResponse(req, 403, "Invite code does not match the authenticated email", {
        invite_code: body.inviteCode,
      });
    }

    const { data: claimedInvite, error: claimError } = await supabase
      .from("clinic_invites")
      .update({
        claimed_by: authUser.id,
        claimed_at: new Date().toISOString(),
      })
      .eq("id", invite.id)
      .is("claimed_at", null)
      .select("id, clinic_id")
      .maybeSingle();

    if (claimError) {
      throw new HttpError(500, "Failed to claim invite code", {
        detail: claimError.message,
      });
    }

    if (!claimedInvite) {
      return errorResponse(req, 409, "Invite code has already been claimed", {
        invite_code: body.inviteCode,
      });
    }

    const appMetadata = isRecord(authUser.app_metadata)
      ? authUser.app_metadata
      : {};
    const userMetadata = isRecord(authUser.user_metadata)
      ? authUser.user_metadata
      : {};
    const authProvider =
      (typeof appMetadata.provider === "string" && appMetadata.provider) ||
      (typeof userMetadata.auth_provider === "string" &&
        userMetadata.auth_provider) ||
      "email";
    const avatarUrl = typeof userMetadata.avatar_url === "string"
      ? userMetadata.avatar_url
      : null;

    const { error: insertUserError } = await supabase
      .from("users")
      .insert({
        id: authUser.id,
        clinic_id: claimedInvite.clinic_id,
        role: "client",
        email: authEmail || `${authUser.id}@placeholder.local`,
        full_name: body.fullName,
        auth_provider: authProvider,
        avatar_url: avatarUrl,
      });

    if (insertUserError) {
      if (insertUserError.code === "23505") {
        const { data: concurrentUser } = await supabase
          .from("users")
          .select("id, clinic_id, role")
          .eq("id", authUser.id)
          .maybeSingle();

        if (
          concurrentUser?.clinic_id === claimedInvite.clinic_id &&
          concurrentUser.role === "client"
        ) {
          // Another onboarding path won the race for this same user; keep the
          // claimed invite and continue as a successful idempotent response.
        } else {
          await rollbackInviteClaim(claimedInvite.id as string, authUser.id);
          return errorResponse(
            req,
            409,
            "Unable to create a unique clinic user record for this account",
            { detail: insertUserError.message },
          );
        }
      } else {
        await rollbackInviteClaim(claimedInvite.id as string, authUser.id);
        throw new HttpError(500, "Failed to create client user record", {
          detail: insertUserError.message,
        });
      }
    }

    const { data: clientProfile, error: clientProfileError } = await supabase
      .from("client_profiles")
      .select("id, clinic_id")
      .eq("user_id", authUser.id)
      .eq("clinic_id", claimedInvite.clinic_id)
      .maybeSingle();

    if (clientProfileError) {
      throw new HttpError(500, "Client onboarding succeeded but client profile lookup failed", {
        detail: clientProfileError.message,
      });
    }

    if (!clientProfile) {
      throw new HttpError(500, "Client onboarding did not create a client profile");
    }

    return jsonResponse(req, {
      success: true,
      clinicId: claimedInvite.clinic_id,
      role: "client",
      clientProfileId: clientProfile.id,
    });
  } catch (err) {
    if (err instanceof HttpError) {
      return errorResponse(req, err.status, err.message, err.details);
    }

    console.error("Unexpected error in claim-clinic-invite:", err);
    return errorResponse(req, 500, "Internal server error");
  }
});
