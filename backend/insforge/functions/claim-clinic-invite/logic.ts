export interface NormalizedClaimClinicInviteRequest {
  inviteCode: string;
  fullName: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readFirst(
  record: Record<string, unknown>,
  keys: string[],
): unknown {
  for (const key of keys) {
    if (key in record) {
      return record[key];
    }
  }

  return undefined;
}

function normalizeRequiredString(
  value: unknown,
  fieldName: string,
  errors: string[],
): string | null {
  if (typeof value !== "string") {
    errors.push(`${fieldName} is required`);
    return null;
  }

  const trimmed = value.trim();
  if (trimmed.length === 0) {
    errors.push(`${fieldName} is required`);
    return null;
  }

  return trimmed;
}

export function normalizeClaimClinicInviteRequest(
  payload: unknown,
): { value: NormalizedClaimClinicInviteRequest | null; errors: string[] } {
  if (!isRecord(payload)) {
    return { value: null, errors: ["Request body must be a JSON object"] };
  }

  const errors: string[] = [];
  const inviteCode = normalizeRequiredString(
    readFirst(payload, ["invite_code", "inviteCode"]),
    "invite_code",
    errors,
  );
  const fullName = normalizeRequiredString(
    readFirst(payload, ["full_name", "fullName"]),
    "full_name",
    errors,
  );

  if (errors.length > 0) {
    return { value: null, errors };
  }

  return {
    value: {
      inviteCode: (inviteCode as string).toUpperCase(),
      fullName: fullName as string,
    },
    errors: [],
  };
}
