"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import type {
  AssessmentRecord,
  BodyRegion,
  ClientProfileRecord,
  SessionConfig,
} from "@hydrascan/shared";
import { useInsforge } from "@/hooks/useInsforge";
import { useRecommendation } from "@/hooks/useRecommendation";
import { formatBodyRegion, formatConfidence, formatRecoveryScore } from "@/lib/formatters";
import { ConfidenceBadge } from "./ConfidenceBadge";
import { ExplanationCard } from "./ExplanationCard";
import { ProtocolCard } from "./ProtocolCard";
import { ProtocolEditor } from "./ProtocolEditor";
import type { RecommendationEnvelope } from "@/components/client-detail/types";

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

function getBodyRegion(
  recommendation: RecommendationEnvelope | null,
  profile: ClientProfileRow | null,
): BodyRegion {
  return (
    recommendation?.data?.recoveryMap?.highlightedRegions?.[0]?.region ??
    profile?.primary_regions?.[0] ??
    "lower_back"
  ) as BodyRegion;
}

function getAssessmentGoal(assessment: ClientAssessmentRow | null) {
  return assessment?.recovery_goal ?? "recovery";
}

function buildPractitionerEdits(recommended: SessionConfig, edited: SessionConfig) {
  const changes: Record<string, unknown> = {};

  const scalarFields: Array<keyof SessionConfig> = [
    "sessionPause",
    "sDelay",
    "edgeCycleDuration",
    "hotDrop",
    "coldDrop",
    "vibMin",
    "vibMax",
    "led",
  ];

  for (const field of scalarFields) {
    if (recommended[field] !== edited[field]) {
      changes[field] = {
        from: recommended[field],
        to: edited[field],
      };
    }
  }

  const hotChanges = edited.pwmValues.hot
    .map((value, index) =>
      value !== recommended.pwmValues.hot[index]
        ? {
            index,
            from: recommended.pwmValues.hot[index],
            to: value,
          }
        : null,
    )
    .filter(Boolean);
  const coldChanges = edited.pwmValues.cold
    .map((value, index) =>
      value !== recommended.pwmValues.cold[index]
        ? {
            index,
            from: recommended.pwmValues.cold[index],
            to: value,
          }
        : null,
    )
    .filter(Boolean);

  if (hotChanges.length > 0 || coldChanges.length > 0) {
    changes.pwmValues = {
      hot: hotChanges,
      cold: coldChanges,
    };
  }

  return changes;
}

export function ProtocolReviewScreen() {
  const insforge = useInsforge();
  const params = useParams<{ clientId: string }>();
  const router = useRouter();
  const searchParams = useSearchParams();
  const clientId = params?.clientId ?? "";
  const requestedAssessmentId = searchParams.get("assessmentId")?.trim() || "";

  const [profile, setProfile] = useState<ClientProfileRow | null>(null);
  const [assessment, setAssessment] = useState<ClientAssessmentRow | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadToken, setReloadToken] = useState(0);
  const [editedConfig, setEditedConfig] = useState<SessionConfig | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function loadProtocolContext() {
      if (!clientId) return;

      setIsLoading(true);
      setError(null);

      const [profileResult, assessmentResult] = await Promise.all([
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

      setProfile((profileResult.data ?? null) as ClientProfileRow | null);
      setAssessment(
        Array.isArray(assessmentResult.data)
          ? ((assessmentResult.data[0] ?? null) as ClientAssessmentRow | null)
          : ((assessmentResult.data ?? null) as ClientAssessmentRow | null),
      );
      setIsLoading(false);
    }

    void loadProtocolContext();

    return () => {
      cancelled = true;
    };
  }, [clientId, requestedAssessmentId, reloadToken, insforge]);

  const recommendation = useRecommendation(clientId, assessment?.id ?? "");
  const recommendationEnvelope = recommendation.recommendation as RecommendationEnvelope | null;
  const recommendationData = recommendationEnvelope?.data ?? null;
  const bodyRegion = getBodyRegion(recommendationEnvelope, profile);
  const clientName = getClientName(profile);
  const recoveryGoal = recommendationData?.recoveryMap?.suggestedGoal ?? getAssessmentGoal(assessment);
  const latestScore = recommendationData?.recoveryScore ?? null;
  const confidence = recommendationData?.confidence ?? 0;
  const isDirty =
    recommendationData?.sessionConfig && editedConfig
      ? JSON.stringify(editedConfig) !== JSON.stringify(recommendationData.sessionConfig)
      : false;

  useEffect(() => {
    if (!recommendationData?.sessionConfig) return;
    if (!editedConfig) {
      setEditedConfig(recommendationData.sessionConfig);
      return;
    }

    if (!isDirty) {
      setEditedConfig(recommendationData.sessionConfig);
    }
  }, [editedConfig, isDirty, recommendationData?.sessionConfig]);

  function handleApprove() {
    if (!recommendationData?.sessionConfig || !editedConfig) return;

    const payload = {
      clientId,
      assessmentId: assessment?.id ?? requestedAssessmentId ?? "",
      bodyRegion,
      recommended_config: recommendationData.sessionConfig,
      practitioner_edits: buildPractitionerEdits(recommendationData.sessionConfig, editedConfig),
      session_config: editedConfig,
      recommendation_rationale: recommendationData.explanation,
      confidence_score: recommendationData.confidence,
    };

    try {
      window.sessionStorage.setItem(
        `hydrawav3.protocol.${clientId}.${assessment?.id ?? requestedAssessmentId ?? "latest"}`,
        JSON.stringify(payload),
      );
    } catch {
      // Session storage is a convenience for the next workflow step.
    }

    router.push(`/clients/${clientId}/session${assessment?.id ? `?assessmentId=${assessment.id}` : ""}`);
  }

  if (isLoading && !profile) {
    return (
      <main className="mx-auto flex w-full max-w-7xl flex-col gap-6 px-4 py-6 sm:px-6 lg:px-8">
        <section className="h-40 animate-pulse rounded-[2rem] bg-slate-100" />
        <section className="grid gap-6 xl:grid-cols-[1fr_320px]">
          <div className="space-y-6">
            <div className="h-72 animate-pulse rounded-[2rem] bg-slate-100" />
            <div className="h-96 animate-pulse rounded-[2rem] bg-slate-100" />
          </div>
          <div className="space-y-6">
            <div className="h-72 animate-pulse rounded-[2rem] bg-slate-100" />
            <div className="h-44 animate-pulse rounded-[2rem] bg-slate-100" />
          </div>
        </section>
      </main>
    );
  }

  if (error) {
    return (
      <main className="mx-auto flex w-full max-w-4xl flex-col gap-4 px-4 py-10 sm:px-6">
        <section className="rounded-[2rem] border border-rose-200 bg-rose-50 p-6 text-rose-900">
          <h1 className="text-2xl font-semibold">Protocol review is unavailable</h1>
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
      <section className="overflow-hidden rounded-[2rem] border border-emerald-100 bg-[linear-gradient(135deg,#0f172a_0%,#111827_45%,#0f766e_100%)] px-6 py-8 text-white shadow-[0_24px_80px_rgba(15,23,42,0.24)] sm:px-8">
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1.2fr)_auto] lg:items-end">
          <div className="space-y-4">
            <p className="text-xs font-semibold uppercase tracking-[0.35em] text-emerald-300">
              Hydrawav3 practitioner dashboard
            </p>
            <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">Protocol review</h1>
            <p className="max-w-2xl text-sm leading-6 text-slate-300 sm:text-base">
              Review the recommended session, adjust safe settings when needed, and keep the
              Hydrawav3 flow moving.
            </p>
            <div className="flex flex-wrap gap-2">
              <span className="rounded-full border border-white/20 bg-white/10 px-3 py-1 text-xs font-medium text-white">
                {clientName}
              </span>
              <span className="rounded-full border border-white/20 bg-white/10 px-3 py-1 text-xs font-medium text-white">
                {formatBodyRegion(bodyRegion)}
              </span>
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
              Confidence {recommendationData ? formatConfidence(confidence) : "Pending"}
            </p>
          </div>
        </div>
      </section>

      <section className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
        <div className="space-y-6">
          {recommendationData ? (
            <ProtocolCard
              sessionConfig={recommendationData.sessionConfig}
              bodyRegion={bodyRegion}
              recoveryGoal={String(recoveryGoal)}
            />
          ) : (
            <div className="rounded-[2rem] border border-dashed border-slate-300 bg-white p-6 text-sm text-slate-600">
              The protocol will appear once the latest recommendation is ready.
            </div>
          )}

          {recommendationData ? (
            <ExplanationCard explanation={recommendationData.explanation} isFallback={false} />
          ) : null}

          {recommendationData && editedConfig ? (
            <ProtocolEditor
              value={editedConfig}
              recommended={recommendationData.sessionConfig}
              bodyRegion={bodyRegion}
              onChange={setEditedConfig}
            />
          ) : null}
        </div>

        <aside className="space-y-6">
          {recommendationData ? <ConfidenceBadge confidence={confidence} /> : null}

          {recommendationData && confidence < 0.5 ? (
            <section className="rounded-[2rem] border border-amber-200 bg-amber-50 p-5 text-amber-900">
              <h2 className="text-lg font-semibold">Limited history</h2>
              <p className="mt-2 text-sm leading-6">
                This recommendation is still useful, but the current history is light. Review the
                values carefully before continuing.
              </p>
            </section>
          ) : null}

          {recommendationData ? (
            <section className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
              <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
                History adjustments
              </p>
              {recommendationData.adjustments.length > 0 ? (
                <ul className="mt-3 space-y-2 text-sm text-slate-700">
                  {recommendationData.adjustments.map((adjustment) => (
                    <li key={adjustment} className="rounded-xl bg-slate-50 px-3 py-2">
                      {adjustment}
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="mt-3 text-sm text-slate-600">No history adjustments were applied.</p>
              )}
            </section>
          ) : null}

          <section className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
              Launch actions
            </p>
            <p className="mt-2 text-sm leading-6 text-slate-600">
              The approved configuration will be passed to the next Hydrawav3 workflow step.
            </p>
            <div className="mt-4 flex flex-col gap-3">
              <button
                type="button"
                onClick={handleApprove}
                disabled={!recommendationData || !editedConfig}
                className="rounded-full bg-slate-950 px-4 py-2 text-sm font-semibold text-white transition disabled:cursor-not-allowed disabled:bg-slate-300"
              >
                Approve and continue
              </button>
              <button
                type="button"
                onClick={() => {
                  if (recommendationData?.sessionConfig) {
                    setEditedConfig(recommendationData.sessionConfig);
                  }
                }}
                disabled={!recommendationData}
                className="rounded-full border border-slate-200 bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-700 transition disabled:cursor-not-allowed disabled:bg-slate-100"
              >
                Reset to recommendation
              </button>
              <Link
                href={`/clients/${clientId}${assessment?.id ? `?assessmentId=${assessment.id}` : ""}`}
                className="rounded-full border border-transparent bg-emerald-50 px-4 py-2 text-center text-sm font-semibold text-emerald-800"
              >
                Back to client
              </Link>
            </div>
          </section>
        </aside>
      </section>
    </main>
  );
}
