const DEFAULT_ALLOWED_HEADERS = "authorization, x-client-info, apikey, content-type";
const DEFAULT_ALLOWED_METHODS = "POST, OPTIONS";

export function buildCorsHeaders(
  request?: Request,
  overrides?: HeadersInit,
): Headers {
  const origin = Deno.env.get("CORS_ALLOW_ORIGIN") ??
    request?.headers.get("Origin") ??
    "*";

  const headers = new Headers({
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": DEFAULT_ALLOWED_HEADERS,
    "Access-Control-Allow-Methods": DEFAULT_ALLOWED_METHODS,
    "Access-Control-Max-Age": "86400",
    "Content-Type": "application/json; charset=utf-8",
  });

  if (request?.headers.get("Origin")) {
    headers.set("Vary", "Origin");
  }

  if (overrides) {
    const overrideHeaders = new Headers(overrides);
    for (const [key, value] of overrideHeaders.entries()) {
      headers.set(key, value);
    }
  }

  return headers;
}

export function handleCors(request: Request): Response | null {
  if (request.method !== "OPTIONS") {
    return null;
  }

  return new Response("ok", {
    status: 200,
    headers: buildCorsHeaders(request),
  });
}

export function jsonResponse(
  request: Request | undefined,
  body: unknown,
  init: ResponseInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: buildCorsHeaders(request, init.headers),
  });
}

export function errorResponse(
  request: Request | undefined,
  status: number,
  error: string,
  details: Record<string, unknown> = {},
): Response {
  return jsonResponse(request, { success: false, error, ...details }, { status });
}

export function methodNotAllowed(
  request: Request,
  allowed = DEFAULT_ALLOWED_METHODS,
): Response {
  return errorResponse(request, 405, `Method ${request.method} is not allowed`, {
    allowed,
  });
}
