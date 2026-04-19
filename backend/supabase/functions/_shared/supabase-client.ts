import {
  createClient,
  type SupabaseClient,
  type User,
} from "https://esm.sh/@supabase/supabase-js@2.49.8";

export type UserRole = "client" | "practitioner" | "admin";

export interface UserProfile {
  id: string;
  clinic_id: string;
  role: UserRole;
  email?: string | null;
  full_name?: string | null;
}

export interface AuthenticatedUserContext {
  token: string;
  authUser: User;
  user: UserProfile;
  clinicId: string;
  role: UserRole;
  supabase: SupabaseClient;
}

export class HttpError extends Error {
  status: number;
  details: Record<string, unknown>;

  constructor(
    status: number,
    message: string,
    details: Record<string, unknown> = {},
  ) {
    super(message);
    this.name = "HttpError";
    this.status = status;
    this.details = details;
  }
}

export function getRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();

  if (!value) {
    throw new HttpError(500, `${name} is not configured`);
  }

  return value;
}

export function createServiceRoleClient(): SupabaseClient {
  return createClient(
    getRequiredEnv("SUPABASE_URL"),
    getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

export function extractBearerToken(request: Request): string {
  const header = request.headers.get("Authorization");

  if (!header) {
    throw new HttpError(401, "Missing Authorization header");
  }

  const [scheme, ...tokenParts] = header.trim().split(/\s+/);

  if (scheme?.toLowerCase() !== "bearer" || tokenParts.length === 0) {
    throw new HttpError(401, "Authorization header must be a Bearer token");
  }

  const token = tokenParts.join(" ").trim();

  if (!token) {
    throw new HttpError(401, "Bearer token is empty");
  }

  return token;
}

export async function requireAuthenticatedUser(
  request: Request,
  supabase = createServiceRoleClient(),
): Promise<AuthenticatedUserContext> {
  const token = extractBearerToken(request);
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    throw new HttpError(401, "Invalid or expired Supabase session", {
      detail: error?.message,
    });
  }

  const { data: userProfile, error: userError } = await supabase
    .from("users")
    .select("id, clinic_id, role, email, full_name")
    .eq("id", data.user.id)
    .maybeSingle();

  if (userError) {
    throw new HttpError(500, "Failed to load user profile", {
      detail: userError.message,
    });
  }

  if (!userProfile?.clinic_id || !userProfile?.role) {
    throw new HttpError(403, "No clinic workspace is assigned to this user");
  }

  return {
    token,
    authUser: data.user,
    user: userProfile as UserProfile,
    clinicId: userProfile.clinic_id as string,
    role: userProfile.role as UserRole,
    supabase,
  };
}

export function requireRole(
  context: AuthenticatedUserContext,
  allowedRoles: UserRole | UserRole[],
): void {
  const allowed = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

  if (!allowed.includes(context.role)) {
    throw new HttpError(
      403,
      `This endpoint requires ${allowed.join(" or ")} access`,
      { role: context.role },
    );
  }
}

export function isSimulationMode(): boolean {
  const baseUrl = Deno.env.get("HYDRAWAV_API_BASE_URL")?.trim();
  return !baseUrl || baseUrl.toLowerCase() === "simulation";
}

export function getHydrawavApiBaseUrl(): string {
  const baseUrl = Deno.env.get("HYDRAWAV_API_BASE_URL")?.trim();

  if (!baseUrl || baseUrl.toLowerCase() === "simulation") {
    throw new HttpError(
      500,
      "HYDRAWAV_API_BASE_URL must be configured for live Hydrawav requests",
    );
  }

  return baseUrl.replace(/\/+$/, "");
}

export function toAuthorizationHeader(token: string): string {
  const trimmed = token.trim();
  if (!trimmed) {
    return trimmed;
  }

  return trimmed.toLowerCase().startsWith("bearer ")
    ? trimmed
    : `Bearer ${trimmed}`;
}
