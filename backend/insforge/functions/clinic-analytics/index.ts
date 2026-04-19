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
} from "../_shared/insforge-client.ts";
import type { InsforgeDataClient } from "../_shared/insforge-client.ts";

// ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Types ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬

interface AnalyticsRequest {
  action:
    | "aggregate"
    | "practitioner"
    | "protocol"
    | "device"
    | "retention"
    | "roi";
  date_range?: { start: string; end: string };
  per_session_revenue?: number;
  monthly_subscription_cost?: number;
}

// ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Action Handlers ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬

async function getAggregateMetrics(
  insforge: InsforgeDataClient,
  clinicId: string,
  dateRange: { start: string; end: string },
) {
  // Clinic metrics from view
  const { data: metrics, error: metricsError } = await insforge
    .from("clinic_metrics_v")
    .select("*")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (metricsError) {
    throw new HttpError(500, "Failed to fetch aggregate metrics", {
      detail: metricsError.message,
    });
  }

  // Recovery Score improvement: mean of (first score - latest score) per client
  const { data: scoreData } = await insforge
    .from("recovery_graph")
    .select("client_id, value, recorded_at")
    .eq("clinic_id", clinicId)
    .eq("metric_type", "recovery_score")
    .order("recorded_at", { ascending: true });

  let avgScoreImprovement = 0;
  if (scoreData && scoreData.length > 0) {
    const clientScores = new Map<string, { first: number; last: number }>();
    for (const row of scoreData) {
      const existing = clientScores.get(row.client_id);
      if (!existing) {
        clientScores.set(row.client_id, {
          first: row.value,
          last: row.value,
        });
      } else {
        existing.last = row.value;
      }
    }
    const improvements = Array.from(clientScores.values()).map(
      (s) => s.last - s.first,
    );
    if (improvements.length > 0) {
      avgScoreImprovement =
        improvements.reduce((a, b) => a + b, 0) / improvements.length;
    }
  }

  // Device utilization
  const { data: devices } = await insforge
    .from("device_utilization_v")
    .select("*")
    .eq("clinic_id", clinicId);

  // Client retention
  const { data: retention } = await insforge
    .from("client_retention_v")
    .select("*")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  return {
    totalSessions: metrics?.total_sessions ?? 0,
    uniqueClients: metrics?.unique_clients ?? 0,
    activePractitioners: metrics?.active_practitioners ?? 0,
    avgImprovement: Number((metrics?.avg_improvement ?? 0).toFixed(3)),
    avgRecoveryScoreImprovement: Number(avgScoreImprovement.toFixed(1)),
    activeClients30d: metrics?.active_clients_30d ?? 0,
    deviceUtilization: (devices ?? []).map((d: Record<string, unknown>) => ({
      deviceId: d.device_id,
      label: d.label,
      room: d.room,
      currentStatus: d.current_status,
      sessionCount: d.session_count,
      lastSessionAt: d.last_session_at,
    })),
    clientRetention: {
      totalClients: retention?.total_clients ?? 0,
      returningClients: retention?.returning_clients ?? 0,
      retentionRate:
        retention && (retention.total_clients as number) > 0
          ? Number(
              (
                ((retention.returning_clients as number) /
                  (retention.total_clients as number)) *
                100
              ).toFixed(1),
            )
          : 0,
      avgSessionsPerClient: Number(
        (retention?.avg_sessions_per_client ?? 0).toFixed(1),
      ),
    },
  };
}

async function getPractitionerMetrics(
  insforge: InsforgeDataClient,
  clinicId: string,
) {
  const { data, error } = await insforge
    .from("practitioner_metrics_v")
    .select("*")
    .eq("clinic_id", clinicId);

  if (error) {
    throw new HttpError(500, "Failed to fetch practitioner metrics", {
      detail: error.message,
    });
  }

  return (data ?? []).map((p: Record<string, unknown>) => {
    // Anonymize: first name or initials only
    const fullName = (p.practitioner_name as string) || "";
    const displayName = fullName.split(" ")[0] || fullName.substring(0, 2);

    return {
      practitionerId: p.practitioner_id,
      displayName,
      totalSessions: p.total_sessions,
      clientCount: p.client_count,
      avgSessionsPerDay: Number(
        ((p.avg_sessions_per_day as number) ?? 0).toFixed(1),
      ),
      avgOutcomeScore: Number(
        ((p.avg_outcome_score as number) ?? 0).toFixed(3),
      ),
    };
  });
}

async function getProtocolEffectiveness(
  insforge: InsforgeDataClient,
  clinicId: string,
) {
  const { data, error } = await insforge
    .from("protocol_effectiveness_v")
    .select("*")
    .eq("clinic_id", clinicId);

  if (error) {
    throw new HttpError(500, "Failed to fetch protocol effectiveness", {
      detail: error.message,
    });
  }

  const protocols = (data ?? []).map((p: Record<string, unknown>) => ({
    recoveryGoal: p.recovery_goal,
    bodyRegion: p.body_region,
    sessionCount: p.session_count,
    avgOutcomeScore: Number(
      ((p.avg_outcome_score as number) ?? 0).toFixed(3),
    ),
    limitedData: p.limited_data as boolean,
  }));

  // Rank top 5 by avg outcome score, excluding limited data
  const ranked = protocols
    .filter((p: { limitedData: boolean }) => !p.limitedData)
    .sort(
      (a: { avgOutcomeScore: number }, b: { avgOutcomeScore: number }) =>
        b.avgOutcomeScore - a.avgOutcomeScore,
    )
    .slice(0, 5);

  return {
    all: protocols,
    topFive: ranked,
  };
}

async function getDeviceUtilization(
  insforge: InsforgeDataClient,
  clinicId: string,
) {
  const { data, error } = await insforge
    .from("device_utilization_v")
    .select("*")
    .eq("clinic_id", clinicId);

  if (error) {
    throw new HttpError(500, "Failed to fetch device utilization", {
      detail: error.message,
    });
  }

  return (data ?? []).map((d: Record<string, unknown>) => ({
    deviceId: d.device_id,
    label: d.label,
    room: d.room,
    deviceMac: d.device_mac,
    currentStatus: d.current_status,
    sessionCount: d.session_count,
    lastSessionAt: d.last_session_at,
  }));
}

async function getRetentionMetrics(
  insforge: InsforgeDataClient,
  clinicId: string,
) {
  const { data, error } = await insforge
    .from("client_retention_v")
    .select("*")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to fetch retention metrics", {
      detail: error.message,
    });
  }

  const totalClients = (data?.total_clients as number) ?? 0;
  const returningClients = (data?.returning_clients as number) ?? 0;

  return {
    totalClients,
    returningClients,
    retentionRate:
      totalClients > 0
        ? Number(((returningClients / totalClients) * 100).toFixed(1))
        : 0,
    avgSessionsPerClient: Number(
      ((data?.avg_sessions_per_client as number) ?? 0).toFixed(1),
    ),
  };
}

function computeROI(input: {
  totalSessions: number;
  uniqueClients: number;
  returningClients: number;
  perSessionRevenue: number;
  monthlySubscriptionCost: number;
}) {
  const totalRevenue = input.totalSessions * input.perSessionRevenue;
  const avgRevenuePerClient =
    input.uniqueClients > 0 ? totalRevenue / input.uniqueClients : 0;
  // Estimate avg retention months from returning client ratio
  const retentionRatio =
    input.uniqueClients > 0
      ? input.returningClients / input.uniqueClients
      : 0;
  const avgRetentionMonths = Math.max(1, Math.round(retentionRatio * 12));
  const estimatedClientLifetimeValue =
    avgRevenuePerClient * avgRetentionMonths;
  const dailyRevenue = totalRevenue / 30;
  const paybackPeriodDays =
    dailyRevenue > 0
      ? Math.ceil(input.monthlySubscriptionCost / dailyRevenue)
      : 999;
  const conversionRate =
    input.uniqueClients > 0
      ? Number(
          (
            (input.returningClients / input.uniqueClients) *
            100
          ).toFixed(1),
        )
      : 0;

  return {
    totalEstimatedRevenue: Number(totalRevenue.toFixed(2)),
    avgRevenuePerClient: Number(avgRevenuePerClient.toFixed(2)),
    estimatedClientLifetimeValue: Number(
      estimatedClientLifetimeValue.toFixed(2),
    ),
    paybackPeriodDays,
    conversionRate,
    perSessionRevenue: input.perSessionRevenue,
  };
}

async function getROIMetrics(
  insforge: InsforgeDataClient,
  clinicId: string,
  perSessionRevenue: number,
  monthlySubscriptionCost: number,
) {
  // Get session and client counts
  const { data: metrics } = await insforge
    .from("clinic_metrics_v")
    .select("total_sessions, unique_clients")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  const { data: retention } = await insforge
    .from("client_retention_v")
    .select("returning_clients")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  return computeROI({
    totalSessions: (metrics?.total_sessions as number) ?? 0,
    uniqueClients: (metrics?.unique_clients as number) ?? 0,
    returningClients: (retention?.returning_clients as number) ?? 0,
    perSessionRevenue,
    monthlySubscriptionCost,
  });
}

// ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ Main Handler ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬

Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return methodNotAllowed(req);
  }

  try {
    const ctx = await requireAuthenticatedUser(req);
    // Analytics available to admins and practitioners
    requireRole(ctx, ["admin", "practitioner"]);

    const body: AnalyticsRequest = await req.json();
    const clinicId = ctx.clinicId;

    const defaultStart = new Date(
      Date.now() - 30 * 24 * 60 * 60 * 1000,
    ).toISOString();
    const _dateRange = body.date_range ?? {
      start: defaultStart,
      end: new Date().toISOString(),
    };

    let result: unknown;

    switch (body.action) {
      case "aggregate":
        result = await getAggregateMetrics(ctx.insforge, clinicId, _dateRange);
        break;
      case "practitioner":
        result = await getPractitionerMetrics(ctx.insforge, clinicId);
        break;
      case "protocol":
        result = await getProtocolEffectiveness(ctx.insforge, clinicId);
        break;
      case "device":
        result = await getDeviceUtilization(ctx.insforge, clinicId);
        break;
      case "retention":
        result = await getRetentionMetrics(ctx.insforge, clinicId);
        break;
      case "roi":
        result = await getROIMetrics(
          ctx.insforge,
          clinicId,
          body.per_session_revenue ?? 15,
          body.monthly_subscription_cost ?? 299,
        );
        break;
      default:
        return errorResponse(req, 400, "Invalid action", {
          allowed: [
            "aggregate",
            "practitioner",
            "protocol",
            "device",
            "retention",
            "roi",
          ],
        });
    }

    return jsonResponse(req, { success: true, action: body.action, data: result });
  } catch (err) {
    if (err instanceof HttpError) {
      return errorResponse(req, err.status, err.message, err.details);
    }
    console.error("Unexpected error in clinic-analytics:", err);
    return errorResponse(req, 500, "Internal server error");
  }
});
