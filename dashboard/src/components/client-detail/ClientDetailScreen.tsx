"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useSearchParams } from "next/navigation";
import type {
  AssessmentRecord,
  BodyRegion,
  ClientProfileRecord,
  RecoveryGraphPoint,
  SessionRecord,
} from "@hydrascan/shared";
import { useInsforge } from "@/hooks/useInsforge";
import { useRecommendation } from "@/hooks/useRecommendation";
import { useRecoveryGraph } from "@/hooks/useRecoveryGraph";
import {
  formatBodyRegion,
  formatRecoveryScore,
} from "@/lib/formatters";
import { ConfidenceBadge } from "@/components/protocol/ConfidenceBadge";
import { RecoveryMapDisplay } from "./RecoveryMapDisplay";
import { RecoveryGraphChart } from "./RecoveryGraphChart";
import { SessionHistoryList } from "./SessionHistoryList";
import { WearableContextCard } from "./WearableContextCard";
import type { RecommendationEnvelope, SessionHistoryItem } from "./types";

type ClientProfileRow = ClientProfileRecord & {
  users?:
    | {
        full_name?: string | null;
      }
    | Array<{
        full_name?: string | null;
      }>
    | null;
};

type ClientAssessmentRow = AssessmentRecord;

function getClientName(profile: ClientProfileRow | null) {
  if (!profile) return "Client";
  const userRecord = Array.isArray(profile.users) ? profile.users[0] : profile.users;
  return userRecord?.full_name?.trim() || "Client";
}

function getSessionDate(session: SessionRecord) {
  return session.completed_at ?? session.updated_at ?? session.created_at;
}

function getSessionHistorySummary(session: SessionRecord) {
  const config = session.session_config as Record<string, unknown> | null;
  if (!config) return "Hydrawav3 session with safe defaults";

  const goal = typeof config.goal === "string" ? config.goal.replace(/_/g, " ") : "Hydrawav3 session";
  const duration =
    typeof config.totalDuration === "number"
      ? `${Math.round(config.totalDuration / 60)} min`
      : typeof config.edgeCycleDuration === "number"
        ? `${config.edgeCycleDuration} min`
        : null;
  const vibration =
    typeof config.vibMin === "number" && typeof config.vibMax === "number"
      ? `Vibration ${config.vibMin}-${config.vibMax}`
      : null;

  return [goal, duration, vibration].filter(Boolean).join(" | ");
}

function getOutcomeRating(outcome: Record<string, unknown> | null) {
  if (!outcome) return null;

  const keys = ["rating", "score", "outcome_score", "recovery_score", "session_rating"];
  for (const key of keys) {
    const value = outcome[key];
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
  }

  return null;
}

function getRecoveryGraphRegions(
  recommendation: RecommendationEnvelope | null,
  profile: ClientProfileRow | null,
): BodyRegion[] {
  const recommendationRegions =
    recommendation?.data?.recoveryMap?.highlightedRegions.map((region) => region.region) ?? [];
  const profileRegions = profile?.primary_regions ?? [];
  return Array.from(new Set([...recommendationRegions, ...profileRegions]));
}

function RecoveryGraphPanel({
  clientId,
  bodyRegion,
}: {
  clientId: string;
  bodyRegion: BodyRegion;
}) {
  const { dataPoints, isLoading, error } = useRecoveryGraph(clientId, bodyRegion, 30);
  return (
    <RecoveryGraphChart
      bodyRegion={bodyRegion}
      dataPoints={dataPoints as RecoveryGraphPoint[]}
      isLoading={isLoading}
      error={error}
    />
  );
}

export function ClientDetailScreen() {
  const insforge = useInsforge();
  const params = useParams<{ clientId: string }>();
  const searchParams = useSearchParams();
  const clientId = params?.clientId ?? "";
  const requestedAssessmentId = searchParams.get("assessmentId")?.trim() || "";

  const [profile, setProfile] = useState<ClientProfileRow | null>(null);
  const [assessment, setAssessment] = useState<ClientAssessmentRow | null>(null);
  const [sessions, setSessions] = useState<SessionRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadToken, setReloadToken] = useState(0);
  const [selectedRegion, setSelectedRegion] = useState<string>("");

  useEffect(() => {
    let cancelled = false;

    async function loadClientDetail() {
      if (!clientId) return;

      setIsLoading(true);
      setError(null);

      const [profileResult, assessmentResult, sessionsResult] = await Promise.all([
        insforge
          .from("client_profiles")
          .select("*, users:user_id(full_name)")
          .eq("id", clientId)
          .maybeSingle(),
        requestedAssessmentId
          ? insforge.from("assessments").select("*").eq("id", requestedAssessmentId).maybeSingle()
          : insforge
              .from("assessments")
              .select("*")
              .eq("client_id", clientId)
              .order("created_at", { ascending: false })
              .limit(1),
        insforge
          .from("sessions")
          .select(
            "id, client_id, status, session_config, practitioner_notes, recommendation_rationale, outcome, completed_at, created_at, updated_at",
          )
          .eq("client_id", clientId)
          .order("created_at", { ascending: false })
          .limit(3),
      ]);

      if (cancelled) return;

      if (profileResult.error) {
        setError(profileResult.error.message);
        setIsLoading(false);
        return;
      }

      if (assessmentResult.error) {
        setError(assessmentResult.error.message);
        setIsLoading(false);
        return;
      }

      if (sessionsResult.error) {
        setError(sessionsResult.error.message);
        setIsLoading(false);
        return;
      }

      setProfile((profileResult.data ?? null) as ClientProfileRow | null);
      setAssessment(
        Array.isArray(assessmentResult.data)
          ? ((assessmentResult.data[0] ?? null) as ClientAssessmentRow | null)
          : ((assessmentResult.data ?? null) as ClientAssessmentRow | null),
      );
      setSessions((sessionsResult.data ?? []) as SessionRecord[]);
      setIsLoading(false);
    }

    void loadClientDetail();

    return () => {
      cancelled = true;
    };
  }, [clientId, requestedAssessmentId, reloadToken, insforge]);

  const recommendation = useRecommendation(clientId, assessment?.id ?? "");
  const recommendationEnvelope = recommendation.recommendation as RecommendationEnvelope | null;
  const recommendationData = recommendationEnvelope?.data ?? null;
  const recoveryMap = recommendationData?.recoveryMap ?? null;
  const currentClientName = getClientName(profile);
  const graphRegions = getRecoveryGraphRegions(recommendationEnvelope, profile);
  const targetRegion = (recoveryMap?.highlightedRegions?.[0]?.region ??
    profile?.primary_regions?.[0] ??
    "lower_back") as BodyRegion;
  const activeRegion = (selectedRegion && graphRegions.includes(selectedRegion as BodyRegion)
    ? (selectedRegion as BodyRegion)
    : targetRegion) as BodyRegion;
  const latestScore = recommendationData?.recoveryScore ?? null;

  useEffect(() => {
    if (graphRegions.length === 0) return;
    if (!selectedRegion || !graphRegions.includes(selectedRegion as BodyRegion)) {
      setSelectedRegion(graphRegions[0]);
    }
  }, [graphRegions, selectedRegion]);

  const historyItems: SessionHistoryItem[] = sessions.map((session) => ({
    id: session.id,
    date: getSessionDate(session),
    configSummary: getSessionHistorySummary(session),
    outcomeRating: getOutcomeRating(session.outcome),
    practitionerNotes: session.practitioner_notes,
  }));

  if (isLoading && !profile) {
    return (
      <main className="mx-auto flex w-full max-w-7xl flex-col gap-6 px-4 py-6 sm:px-6 lg:px-8">
        <section className="h-44 animate-pulse rounded-[2rem] bg-slate-100" />
        <section className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
          <div className="space-y-6">
            <div className="h-[32rem] animate-pulse rounded-[2rem] bg-slate-100" />
            <div className="h-72 animate-pulse rounded-[2rem] bg-slate-100" />
            <div className="h-56 animate-pulse rounded-[2rem] bg-slate-100" />
          </div>
          <div className="space-y-6">
            <div className="h-56 animate-pulse rounded-[2rem] bg-slate-100" />
            <div className="h-72 animate-pulse rounded-[2rem] bg-slate-100" />
          </div>
        </section>
      </main>
    );
  }

  if (error) {
    return (
      <main className="mx-auto flex w-full max-w-4xl flex-col gap-4 px-4 py-10 sm:px-6">
        <section className="rounded-[2rem] border border-rose-200 bg-rose-50 p-6 text-rose-900">
          <h1 className="text-2xl font-semibold">Client detail is unavailable</h1>
          <p className="mt-2 text-sm text-rose-800">{error}</p>
          <button
            type="button"
            onClick={() => setReloadToken((token) => token + 1)}
            className="mt-4 rounded-full bg-rose-600 px-4 py-2 text-sm font-semibold text-white"
          >
            Retry
          </button>
        </section>
      </main>
    );
  }

  return (
    <main className="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 py-6 sm:px-6 lg:px-8">
      <section className="overflow-hidden rounded-[2rem] border border-emerald-100 bg-[linear-gradient(135deg,#0f172a_0%,#111827_50%,#0f766e_100%)] px-6 py-8 text-white shadow-[0_24px_80px_rgba(15,23,42,0.24)] sm:px-8">
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1.2fr)_auto] lg:items-end">
          <div className="space-y-4">
            <p className="text-xs font-semibold uppercase tracking-[0.35em] text-emerald-300">
              Hydrawav3 practitioner dashboard
            </p>
            <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">{currentClientName}</h1>
            <p className="max-w-2xl text-sm leading-6 text-slate-300 sm:text-base">
              Review the client movement insights, understand the current recommendation, and move
              toward a Hydrawav3 session without breaking flow.
            </p>
            <div className="flex flex-wrap gap-2">
              {(profile?.primary_regions ?? []).map((region) => (
                <span
                  key={region}
                  className="rounded-full border border-white/20 bg-white/10 px-3 py-1 text-xs font-medium text-white"
                >
                  {formatBodyRegion(region)}
                </span>
              ))}
            </div>
          </div>

          <div className="rounded-[1.5rem] border border-white/10 bg-white/10 p-4 backdrop-blur">
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-emerald-200">
              Current recovery score
            </p>
            <p className="mt-2 text-3xl font-semibold">
              {latestScore == null ? "Pending" : formatRecoveryScore(latestScore)}
            </p>
            <p className="mt-2 text-sm text-slate-200">
              Latest assessment:{" "}
              {assessment?.created_at ? new Date(assessment.created_at).toLocaleString() : "Not yet captured"}
            </p>
          </div>
        </div>

        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            href={`/clients/${clientId}/protocol${assessment?.id ? `?assessmentId=${assessment.id}` : ""}`}
            className="rounded-full bg-white px-4 py-2 text-sm font-semibold text-slate-950 transition hover:bg-slate-100"
          >
            Review protocol
          </Link>
          <Link
            href={`/clients/${clientId}/session${assessment?.id ? `?assessmentId=${assessment.id}` : ""}`}
            className="rounded-full border border-white/20 bg-white/10 px-4 py-2 text-sm font-semibold text-white transition hover:bg-white/15"
          >
            Approve and continue
          </Link>
          <button
            type="button"
            onClick={() => setReloadToken((token) => token + 1)}
            className="rounded-full border border-white/20 bg-white/10 px-4 py-2 text-sm font-semibold text-white transition hover:bg-white/15"
          >
            Refresh context
          </button>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[minmax(0,1.15fr)_minmax(0,0.85fr)]">
        <div className="space-y-6">
          <RecoveryMapDisplay recoveryMap={recoveryMap} primaryRegion={targetRegion} />

          <div className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
                  Region graph
                </p>
                <h2 className="mt-1 text-xl font-semibold text-slate-950">
                  Select a region for the trend view
                </h2>
              </div>
              {graphRegions.length > 0 ? (
                <div className="flex flex-wrap gap-2">
                  {graphRegions.map((region) => (
                    <button
                      type="button"
                      key={region}
                      onClick={() => setSelectedRegion(region)}
                      className={[
                        "rounded-full px-3 py-1 text-xs font-semibold transition",
                        activeRegion === region
                          ? "bg-slate-950 text-white"
                          : "border border-slate-200 bg-slate-50 text-slate-700",
                      ].join(" ")}
                    >
                      {formatBodyRegion(region)}
                    </button>
                  ))}
                </div>
              ) : null}
            </div>

            <div className="mt-4">
              {graphRegions.length > 0 ? (
                <RecoveryGraphPanel key={activeRegion} clientId={clientId} bodyRegion={activeRegion} />
              ) : (
                <div className="rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-5 text-sm text-slate-600">
                  Select a client region to show the trend chart.
                </div>
              )}
            </div>
          </div>

          <SessionHistoryList sessions={historyItems} />
        </div>

        <div className="space-y-6">
          {profile?.wearable_hrv != null &&
          profile.wearable_strain != null &&
          profile.wearable_sleep_score != null &&
          profile.wearable_last_sync ? (
            <WearableContextCard
              wearable={{
                hrv: profile.wearable_hrv,
                strain: profile.wearable_strain,
                sleepScore: profile.wearable_sleep_score,
                lastSync: profile.wearable_last_sync,
              }}
            />
          ) : null}

          <section className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
                  Recommendation summary
                </p>
                <h2 className="mt-1 text-xl font-semibold text-slate-950">
                  Why this protocol was chosen
                </h2>
              </div>
              {recommendationData ? <ConfidenceBadge confidence={recommendationData.confidence} /> : null}
            </div>

            {recommendationData ? (
              <div className="mt-4 space-y-4">
                <p className="text-sm leading-7 text-slate-700">{recommendationData.explanation}</p>

                <div className="rounded-2xl bg-slate-50 p-4">
                  <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                    History adjustments
                  </p>
                  {recommendationData.adjustments.length > 0 ? (
                    <ul className="mt-2 space-y-2 text-sm text-slate-700">
                      {recommendationData.adjustments.map((adjustment) => (
                        <li key={adjustment} className="rounded-xl bg-white px-3 py-2">
                          {adjustment}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="mt-2 text-sm text-slate-600">
                      No history adjustments were applied.
                    </p>
                  )}
                </div>

                <div className="flex flex-wrap gap-3">
                  <Link
                    href={`/clients/${clientId}/protocol${assessment?.id ? `?assessmentId=${assessment.id}` : ""}`}
                    className="rounded-full bg-slate-950 px-4 py-2 text-sm font-semibold text-white"
                  >
                    Edit protocol
                  </Link>
                  <Link
                    href={`/clients/${clientId}/session${assessment?.id ? `?assessmentId=${assessment.id}` : ""}`}
                    className="rounded-full border border-slate-200 bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-700"
                  >
                    Continue to Hydrawav3 launch
                  </Link>
                </div>
              </div>
            ) : (
              <div className="mt-4 rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-4 text-sm text-slate-600">
                The recommendation will appear after the latest assessment is available.
              </div>
            )}
          </section>
        </div>
      </section>
    </main>
  );
}
