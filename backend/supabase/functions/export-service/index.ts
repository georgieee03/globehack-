import {
  handleCors,
  jsonResponse,
  errorResponse,
  methodNotAllowed,
} from "../_shared/cors.ts";
import {
  requireAuthenticatedUser,
  requireRole,
  HttpError,
} from "../_shared/supabase-client.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

// ─── Types ───────────────────────────────────────────────────────────────────

interface ExportRequest {
  format: "csv" | "pdf";
  date_range?: { start: string; end: string };
}

// ─── CSV Generation ──────────────────────────────────────────────────────────

function anonymizeName(fullName: string): string {
  if (!fullName) return "N/A";
  const parts = fullName.trim().split(/\s+/);
  if (parts.length >= 2) {
    return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
  }
  return fullName.substring(0, 2).toUpperCase();
}

async function generateCSV(
  supabase: SupabaseClient,
  clinicId: string,
  dateRange: { start: string; end: string },
): Promise<string> {
  const rows: string[] = [];

  // Header section
  rows.push("HydraScan Clinic Export");
  rows.push(`Date Range,${dateRange.start},${dateRange.end}`);
  rows.push("");

  // Session summary data
  rows.push("SESSION SUMMARY");
  rows.push(
    "Date,Client,Practitioner,Device,Duration (s),Stiffness Before,Stiffness After,Outcome Score",
  );

  const { data: sessions } = await supabase
    .from("sessions")
    .select(`
      id,
      created_at,
      total_duration_s,
      client_profiles!inner (user_id, users:user_id (full_name)),
      users!sessions_practitioner_id_fkey (full_name),
      devices!inner (label),
      outcomes (stiffness_before, stiffness_after, recorded_by)
    `)
    .eq("clinic_id", clinicId)
    .eq("status", "completed")
    .gte("created_at", dateRange.start)
    .lte("created_at", dateRange.end)
    .order("created_at", { ascending: false });

  for (const s of sessions ?? []) {
    const session = s as Record<string, unknown>;
    const clientProfile = session.client_profiles as Record<string, unknown>;
    const clientUser = clientProfile?.users as Record<string, unknown>;
    const practitioner = session.users as Record<string, unknown>;
    const device = session.devices as Record<string, unknown>;
    const outcomes = session.outcomes as Array<Record<string, unknown>>;
    const practOutcome = outcomes?.find(
      (o) => o.recorded_by === "practitioner",
    );

    const clientName = anonymizeName(
      (clientUser?.full_name as string) || "",
    );
    const practName = anonymizeName(
      (practitioner?.full_name as string) || "",
    );
    const stiffBefore = practOutcome?.stiffness_before ?? "";
    const stiffAfter = practOutcome?.stiffness_after ?? "";
    const outcomeScore =
      practOutcome?.stiffness_before != null &&
      practOutcome?.stiffness_after != null
        ? (
            ((practOutcome.stiffness_before as number) -
              (practOutcome.stiffness_after as number)) /
            10
          ).toFixed(2)
        : "";

    const date = new Date(session.created_at as string)
      .toISOString()
      .split("T")[0];

    rows.push(
      `${date},${clientName},${practName},${device?.label ?? ""},${session.total_duration_s ?? ""},${stiffBefore},${stiffAfter},${outcomeScore}`,
    );
  }

  rows.push("");

  // Aggregate metrics
  rows.push("AGGREGATE METRICS");
  const { data: metrics } = await supabase
    .from("clinic_metrics_v")
    .select("*")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  rows.push(`Total Sessions,${metrics?.total_sessions ?? 0}`);
  rows.push(`Unique Clients,${metrics?.unique_clients ?? 0}`);
  rows.push(
    `Average Improvement,${Number((metrics?.avg_improvement ?? 0)).toFixed(3)}`,
  );

  const { data: retention } = await supabase
    .from("client_retention_v")
    .select("*")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  const totalClients = (retention?.total_clients as number) ?? 0;
  const returningClients = (retention?.returning_clients as number) ?? 0;
  const retentionRate =
    totalClients > 0
      ? ((returningClients / totalClients) * 100).toFixed(1)
      : "0";
  rows.push(`Retention Rate,${retentionRate}%`);

  rows.push("");

  // Protocol effectiveness
  rows.push("PROTOCOL EFFECTIVENESS");
  rows.push("Recovery Goal,Body Region,Sessions,Avg Outcome Score,Limited Data");

  const { data: protocols } = await supabase
    .from("protocol_effectiveness_v")
    .select("*")
    .eq("clinic_id", clinicId);

  for (const p of protocols ?? []) {
    const proto = p as Record<string, unknown>;
    rows.push(
      `${proto.recovery_goal ?? ""},${proto.body_region ?? ""},${proto.session_count},${Number((proto.avg_outcome_score as number) ?? 0).toFixed(3)},${proto.limited_data}`,
    );
  }

  return rows.join("\n");
}

// ─── PDF Generation (simplified text-based) ──────────────────────────────────

async function generatePDFContent(
  supabase: SupabaseClient,
  clinicId: string,
  dateRange: { start: string; end: string },
): Promise<string> {
  // Get clinic info
  const { data: clinic } = await supabase
    .from("clinics")
    .select("name")
    .eq("id", clinicId)
    .maybeSingle();

  const { data: metrics } = await supabase
    .from("clinic_metrics_v")
    .select("*")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  const { data: practitioners } = await supabase
    .from("practitioner_metrics_v")
    .select("*")
    .eq("clinic_id", clinicId);

  const { data: devices } = await supabase
    .from("device_utilization_v")
    .select("*")
    .eq("clinic_id", clinicId);

  // Build a structured text report (in production, use a PDF library)
  const lines: string[] = [];
  lines.push("═══════════════════════════════════════════════════");
  lines.push(`  HydraScan Clinic Report`);
  lines.push(`  ${clinic?.name ?? "Clinic"}`);
  lines.push(`  ${dateRange.start} to ${dateRange.end}`);
  lines.push("═══════════════════════════════════════════════════");
  lines.push("");
  lines.push("AGGREGATE METRICS");
  lines.push(`  Total Sessions: ${metrics?.total_sessions ?? 0}`);
  lines.push(`  Unique Clients: ${metrics?.unique_clients ?? 0}`);
  lines.push(
    `  Avg Improvement: ${Number((metrics?.avg_improvement ?? 0)).toFixed(3)}`,
  );
  lines.push(
    `  Active Clients (30d): ${metrics?.active_clients_30d ?? 0}`,
  );
  lines.push("");
  lines.push("PRACTITIONER PERFORMANCE");
  for (const p of practitioners ?? []) {
    const pract = p as Record<string, unknown>;
    const displayName = ((pract.practitioner_name as string) || "")
      .split(" ")[0];
    lines.push(
      `  ${displayName}: ${pract.total_sessions} sessions, ${pract.client_count} clients, avg score ${Number((pract.avg_outcome_score as number) ?? 0).toFixed(3)}`,
    );
  }
  lines.push("");
  lines.push("DEVICE UTILIZATION");
  for (const d of devices ?? []) {
    const dev = d as Record<string, unknown>;
    lines.push(
      `  ${dev.label} (${dev.room ?? "unassigned"}): ${dev.session_count} sessions, status: ${dev.current_status}`,
    );
  }

  return lines.join("\n");
}

// ─── Main Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return methodNotAllowed(req);
  }

  try {
    const ctx = await requireAuthenticatedUser(req);
    requireRole(ctx, "admin");

    const body: ExportRequest = await req.json();

    if (!body.format || !["csv", "pdf"].includes(body.format)) {
      return errorResponse(req, 400, "format must be 'csv' or 'pdf'");
    }

    const defaultStart = new Date(
      Date.now() - 30 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const dateRange = body.date_range ?? {
      start: defaultStart,
      end: new Date().toISOString(),
    };

    let content: string;
    let contentType: string;
    let fileExtension: string;

    if (body.format === "csv") {
      content = await generateCSV(ctx.supabase, ctx.clinicId, dateRange);
      contentType = "text/csv";
      fileExtension = "csv";
    } else {
      content = await generatePDFContent(
        ctx.supabase,
        ctx.clinicId,
        dateRange,
      );
      contentType = "text/plain"; // Simplified; production would use actual PDF
      fileExtension = "txt"; // Would be .pdf with a real PDF library
    }

    // Upload to Supabase Storage
    const fileName = `exports/clinic-report-${Date.now()}.${fileExtension}`;
    const { error: uploadError } = await ctx.supabase.storage
      .from("clinic-exports")
      .upload(fileName, new Blob([content], { type: contentType }), {
        contentType,
        upsert: false,
      });

    if (uploadError) {
      // If bucket doesn't exist, return content directly
      console.warn("Storage upload failed, returning content directly:", uploadError.message);
      return jsonResponse(req, {
        success: true,
        format: body.format,
        generatedAt: new Date().toISOString(),
        content,
        note: "Direct content returned; configure Supabase Storage bucket 'clinic-exports' for file downloads.",
      });
    }

    // Generate signed URL
    const { data: signedUrl } = await ctx.supabase.storage
      .from("clinic-exports")
      .createSignedUrl(fileName, 3600); // 1 hour expiry

    return jsonResponse(req, {
      success: true,
      downloadUrl: signedUrl?.signedUrl ?? null,
      format: body.format,
      generatedAt: new Date().toISOString(),
    });
  } catch (err) {
    if (err instanceof HttpError) {
      return errorResponse(req, err.status, err.message, err.details);
    }
    console.error("Unexpected error in export-service:", err);
    return errorResponse(req, 500, "Internal server error");
  }
});
