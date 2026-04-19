import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/cors.ts";
import {
  createServiceRoleClient,
  getHydrawavApiBaseUrl,
  HttpError,
  isSimulationMode,
  requireAuthenticatedUser,
  requireRole,
} from "../_shared/supabase-client.ts";

interface HydrawavAuthRequest {
  username: string;
  password: string;
}

interface HydrawavLoginResponse {
  JWT_REFRESH_TOKEN?: string;
  JWT_ACCESS_TOKEN?: string;
  refresh_token?: string;
  access_token?: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseHydrawavAuthRequest(value: unknown): HydrawavAuthRequest {
  if (!isRecord(value)) {
    throw new HttpError(400, "Request body must be a JSON object");
  }

  const username = typeof value.username === "string"
    ? value.username.trim()
    : "";
  const password = typeof value.password === "string" ? value.password : "";

  if (!username) {
    throw new HttpError(400, "username is required");
  }

  if (password.trim() === "") {
    throw new HttpError(400, "password is required");
  }

  return { username, password };
}

serve(async (request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) {
    return corsResponse;
  }

  if (request.method !== "POST") {
    return methodNotAllowed(request);
  }

  const supabase = createServiceRoleClient();

  try {
    const context = await requireAuthenticatedUser(request, supabase);
    requireRole(context, "admin");

    const rawBody = await request.json().catch(() => {
      throw new HttpError(400, "Request body must be valid JSON");
    });
    const credentials = parseHydrawavAuthRequest(rawBody);

    if (isSimulationMode()) {
      const { error } = await supabase.from("clinic_hw_tokens").upsert(
        {
          clinic_id: context.clinicId,
          access_token: "Bearer simulated-access-token",
          refresh_token: "Bearer simulated-refresh-token",
          updated_at: new Date().toISOString(),
        },
        { onConflict: "clinic_id" },
      );

      if (error) {
        throw new HttpError(500, "Failed to store simulated Hydrawav tokens", {
          detail: error.message,
        });
      }

      return jsonResponse(request, {
        success: true,
        simulated: true,
      }, { status: 200 });
    }

    let authResponse: Response;
    try {
      authResponse = await fetch(
        `${getHydrawavApiBaseUrl()}/api/v1/auth/login`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            username: credentials.username,
            password: credentials.password,
            rememberMe: true,
          }),
        },
      );
    } catch (error) {
      throw new HttpError(502, "Hydrawav3 auth request could not be completed", {
        detail: error instanceof Error ? error.message : String(error),
      });
    }

    const rawResponse = await authResponse.text();

    if (!authResponse.ok) {
      return errorResponse(request, 401, "Hydrawav3 auth failed", {
        detail: rawResponse || `Hydrawav3 returned ${authResponse.status}`,
      });
    }

    let tokens: HydrawavLoginResponse;
    try {
      tokens = rawResponse ? JSON.parse(rawResponse) as HydrawavLoginResponse : {};
    } catch {
      throw new HttpError(502, "Hydrawav3 auth response was not valid JSON");
    }

    const accessToken = tokens.JWT_ACCESS_TOKEN ?? tokens.access_token;
    const refreshToken = tokens.JWT_REFRESH_TOKEN ?? tokens.refresh_token;

    if (
      typeof accessToken !== "string" || accessToken.trim() === "" ||
      typeof refreshToken !== "string" || refreshToken.trim() === ""
    ) {
      throw new HttpError(
        502,
        "Hydrawav3 auth response did not include both tokens",
      );
    }

    const { error } = await supabase.from("clinic_hw_tokens").upsert(
      {
        clinic_id: context.clinicId,
        access_token: accessToken,
        refresh_token: refreshToken,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "clinic_id" },
    );

    if (error) {
      throw new HttpError(500, "Failed to store Hydrawav tokens", {
        detail: error.message,
      });
    }

    return jsonResponse(request, {
      success: true,
      simulated: false,
    }, { status: 200 });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(request, error.status, error.message, error.details);
    }

    console.error("hydrawav-auth unexpected error", error);
    return errorResponse(request, 500, "Unexpected server error");
  }
});
