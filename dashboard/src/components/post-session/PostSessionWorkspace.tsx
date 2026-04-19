"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import type { AssessmentRecord, ClientProfileRecord, SessionRecord } from "@hydrascan/shared";
import { useInsforge } from "@/hooks/useInsforge";
import { formatConfidence } from "@/lib/formatters";
import { RetestComparison } from "./RetestComparison";
import { SessionNotesEditor } from "./SessionNotesEditor";

interface PostSessionWorkspaceProps {
  clientId: string;
}

export function PostSessionWorkspace({ clientId }: PostSessionWorkspaceProps) {
  const insforge = useInsforge();
  const router = useRouter();
  const searchParams = useSearchParams();
  const sessionId = searchParams.get("sessionId");

  const [session, setSession] = useState<SessionRecord | null>(null);
  const [assessment, setAssessment] = useState<AssessmentRecord | null>(null);
  const [clientProfile, setClientProfile] = useState<ClientProfileRecord | null>(null);
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoading(true);
      setErrorMessage(null);

      const { data: profile, error: profileError } = await insforge.from("client_profiles").select("*").eq("id", clientId).maybeSingle();
      if (cancelled) return;
      if (profileError) {
        setErrorMessage(profileError.message);
        setLoading(false);
        return;
      }
      setClientProfile(profile as ClientProfileRecord | null);

      const sessionQuery = sessionId
        ? insforge.from("sessions").select("*").eq("id", sessionId).maybeSingle()
        : insforge.from("sessions").select("*").eq("client_id", clientId).eq("status", "completed").order("completed_at", { ascending: false }).limit(1).maybeSingle();

      const { data: sessionRow, error: sessionError } = await sessionQuery;
      if (cancelled) return;
      if (sessionError) {
        setErrorMessage(sessionError.message);
        setLoading(false);
        return;
      }

      const currentSession = sessionRow as SessionRecord | null;
      setSession(currentSession);

      if (currentSession?.assessment_id) {
        const { data: assessmentRow } = await insforge.from("assessments").select("*").eq("id", currentSession.assessment_id).maybeSingle();
        if (!cancelled) {
          setAssessment(assessmentRow as AssessmentRecord | null);
        }
      }

      if (!cancelled) {
        setLoading(false);
      }
    }

    void load();

    return () => {
      cancelled = true;
    };
  }, [clientId, sessionId, insforge]);

  if (loading) {
    return (
      <div className="space-y-4">
        <div className="h-24 animate-pulse rounded-3xl bg-slate-100" />
        <div className="h-80 animate-pulse rounded-3xl bg-slate-100" />
      </div>
    );
  }

  if (errorMessage) {
    return <div className="rounded-3xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">{errorMessage}</div>;
  }

  if (!session) {
    return (
      <div className="rounded-3xl border border-dashed border-slate-300 bg-white p-6 text-sm text-slate-600">
        No completed session was found for this client yet.
      </div>
    );
  }

  const preNotes = session.practitioner_notes ?? "";

  return (
    <div className="space-y-6">
      <div className="rounded-[2rem] border border-slate-200 bg-gradient-to-br from-slate-950 via-slate-900 to-slate-800 p-6 text-white shadow-xl">
        <p className="text-xs uppercase tracking-[0.28em] text-slate-300">Post-session workflow</p>
        <h1 className="mt-3 text-3xl font-semibold">Review the outcome and capture next steps</h1>
        <p className="mt-3 max-w-3xl text-sm leading-6 text-slate-300">
          {clientProfile?.notes ? "You can re-test the primary regions, review the ROM deltas, and save session notes before you move on." : "The post-session summary is ready for review."}
        </p>
      </div>

      <RetestComparison
        session={session}
        assessment={assessment}
        onRetest={() => router.push(`/clients/${clientId}/session?sessionId=${session.id}&mode=retest`)}
      />

      <div className="grid gap-4 lg:grid-cols-[1fr_0.8fr]">
        <div className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm">
          <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Session summary</p>
          <div className="mt-4 grid gap-3 text-sm sm:grid-cols-2">
            <div className="rounded-2xl bg-slate-50 p-4">
              <p className="text-xs uppercase tracking-[0.18em] text-slate-500">Status</p>
              <p className="mt-1 font-semibold text-slate-950">{session.status}</p>
            </div>
            <div className="rounded-2xl bg-slate-50 p-4">
              <p className="text-xs uppercase tracking-[0.18em] text-slate-500">Recommendation confidence</p>
              <p className="mt-1 font-semibold text-slate-950">{session.confidence_score != null ? formatConfidence(session.confidence_score) : "Not recorded"}</p>
            </div>
            <div className="rounded-2xl bg-slate-50 p-4 sm:col-span-2">
              <p className="text-xs uppercase tracking-[0.18em] text-slate-500">Recommendation rationale</p>
              <p className="mt-1 leading-6 text-slate-700">{session.recommendation_rationale ?? "No rationale was stored for this session."}</p>
            </div>
          </div>
        </div>

        <SessionNotesEditor
          sessionId={session.id}
          initialNotes={preNotes}
          onSaved={(notes) => setSession((current) => (current ? { ...current, practitioner_notes: notes } : current))}
        />
      </div>
    </div>
  );
}
