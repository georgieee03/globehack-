import {
  createClient,
  type ClientOptions,
  type InsForgeClient,
  type InsForgeError,
  type UserSchema,
} from "npm:@insforge/sdk@1.2.5";

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
  authUser: UserSchema;
  user: UserProfile;
  clinicId: string;
  role: UserRole;
  insforge: InsforgeAdminClient;
}

export interface InsforgeAdminClient {
  auth: {
    getUser: (
      token: string,
    ) => Promise<{ data: { user: UserSchema | null }; error: InsForgeError | null }>;
  };
  database: InsForgeClient["database"];
  storage: InsForgeClient["storage"];
  functions: InsForgeClient["functions"];
  from: InsForgeClient["database"]["from"];
  rpc: InsForgeClient["database"]["rpc"];
}

export type InsforgeDataClient = Pick<
  InsforgeAdminClient,
  "from" | "rpc" | "storage"
>;

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

function createSdkClient(config: ClientOptions): InsForgeClient {
  return createClient({
    autoRefreshToken: false,
    isServerMode: true,
    ...config,
  });
}

function getBaseClientOptions(): Pick<ClientOptions, "baseUrl"> {
  return {
    baseUrl: getRequiredEnv("INSFORGE_URL"),
  };
}

export function createInsforgeAdminClient(): InsforgeAdminClient {
  const sdk = createSdkClient({
    ...getBaseClientOptions(),
    anonKey: getRequiredEnv("INSFORGE_SERVICE_TOKEN"),
  });

  return {
    auth: {
      async getUser(token: string) {
        const authClient = createSdkClient({
          ...getBaseClientOptions(),
          edgeFunctionToken: token,
        });
        const { data, error } = await authClient.auth.getCurrentUser();
        return {
          data: {
            user: data.user,
          },
          error,
        };
      },
    },
    database: sdk.database,
    storage: sdk.storage,
    functions: sdk.functions,
    from: sdk.database.from.bind(sdk.database),
    rpc: sdk.database.rpc.bind(sdk.database),
  };
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
  insforge = createInsforgeAdminClient(),
): Promise<AuthenticatedUserContext> {
  const token = extractBearerToken(request);
  const { data, error } = await insforge.auth.getUser(token);

  if (error || !data.user) {
    throw new HttpError(401, "Invalid or expired InsForge session", {
      detail: error?.message,
    });
  }

  const { data: userProfile, error: userError } = await insforge
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
    insforge,
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
