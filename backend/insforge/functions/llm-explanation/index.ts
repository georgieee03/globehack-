import { handleCors, jsonResponse, errorResponse, methodNotAllowed } from "../_shared/cors.ts";
import { requireAuthenticatedUser, HttpError } from "../_shared/insforge-client.ts";
import { buildPrompt, type LlmExplanationRequest } from "./prompt-builder.ts";
import { generateFallbackExplanation } from "./fallback-template.ts";

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;
  if (req.method !== "POST") return methodNotAllowed(req);

  try {
    await requireAuthenticatedUser(req);
    const body: LlmExplanationRequest = await req.json();
    const prompt = buildPrompt(body);

    const llmApiKey = Deno.env.get("LLM_API_KEY")?.trim();
    if (!llmApiKey) {
      // No API key configured â€” use fallback
      return jsonResponse(req, {
        explanation: generateFallbackExplanation(body),
        isFallback: true,
      });
    }

    // Call LLM API with 3-second timeout
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
        return jsonResponse(req, {
          explanation: generateFallbackExplanation(body),
          isFallback: true,
        });
      }

      const result = await response.json();
      const explanation = result?.content?.[0]?.text ?? generateFallbackExplanation(body);

      return jsonResponse(req, {
        explanation,
        isFallback: !result?.content?.[0]?.text,
      });
    } catch {
      clearTimeout(timeout);
      return jsonResponse(req, {
        explanation: generateFallbackExplanation(body),
        isFallback: true,
      });
    }
  } catch (err) {
    if (err instanceof HttpError) {
      return errorResponse(req, err.status, err.message, err.details);
    }
    return errorResponse(req, 500, "Internal server error");
  }
});
