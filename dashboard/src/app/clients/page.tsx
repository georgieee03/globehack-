"use client";

import { useEffect, useState } from "react";
import { useInsforge } from "@/hooks/useInsforge";
import {
  ClientListTable,
  type ClientListItem,
  type ClientListSortMode,
  sortClients,
} from "@/components/client-list";
import type { ClientProfileRecord, SessionStatus } from "@hydrascan/shared";

type SessionRow = {
  id: string;
  client_id: string;
  status: SessionStatus;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
};

type ClientProfileRow = ClientProfileRecord & {
  users?: {
    full_name?: string | null;
  } | Array<{
    full_name?: string | null;
  }> | null;
};

type RecoveryGraphRow = {
  id: string;
  client_id: string;
  metric_type: string;
  value: number;
  recorded_at: string;
};

function getLatestTimestamp(...values: Array<string | null | undefined>): string | null {
  const timestamps = values.filter((value): value is string => Boolean(value));
  if (timestamps.length === 0) return null;

  return timestamps.reduce((latest, current) => {
    return new Date(current).getTime() > new Date(latest).getTime() ? current : latest;
  });
}

function getRecentActivityAt(profile: ClientProfileRecord, sessions: SessionRow[]): string {
  const latestSession = sessions[0];
  const latestSessionAt = latestSession
    ? getLatestTimestamp(
        latestSession.completed_at,
        latestSession.started_at,
        latestSession.updated_at,
        latestSession.created_at,
      )
    : null;

  return latestSessionAt ?? profile.updated_at ?? profile.created_at;
}

function getNextSessionStatus(sessions: SessionRow[]): string {
  if (sessions.length === 0) return "Assessment ready";

  const latestSession = sessions[0];
  if (latestSession.status === "active" || latestSession.status === "paused") {
    return "In session";
  }

  return "Awaiting session";
}

function buildClientList(
  profiles: ClientProfileRow[],
  sessionsByClient: Map<string, SessionRow[]>,
  recoveryScoreByClient: Map<string, number>,
): ClientListItem[] {
  return profiles.map((profile) => {
    const sessions = sessionsByClient.get(profile.id) ?? [];
    const primaryRegions = profile.primary_regions ?? [];
    const latestActivityAt = getRecentActivityAt(profile, sessions);
    const latestSession = sessions[0] ?? null;
    const latestSessionDate = latestSession
      ? getLatestTimestamp(
          latestSession.completed_at,
          latestSession.started_at,
          latestSession.updated_at,
          latestSession.created_at,
        )
      : null;

    return {
      id: profile.id,
      fullName:
        (Array.isArray(profile.users)
          ? profile.users[0]?.full_name
          : profile.users?.full_name
        )?.trim() || "Client",
      latestRecoveryScore: recoveryScoreByClient.get(profile.id) ?? null,
      primaryRegions,
      mostRecentSessionDate: latestSessionDate,
      nextSessionStatus: getNextSessionStatus(sessions),
      activityAt: latestActivityAt,
      sessionCount: sessions.length,
    };
  });
}

export default function ClientListPage() {
  const insforge = useInsforge();
  const [clients, setClients] = useState<ClientListItem[]>([]);
  const [sortMode, setSortMode] = useState<ClientListSortMode>("recent");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadToken, setReloadToken] = useState(0);

  useEffect(() => {
    let cancelled = false;

    async function loadClients() {
      setIsLoading(true);
      setError(null);

      const { data: profiles, error: profileError } = await insforge
        .from("client_profiles")
        .select("*, users:user_id(full_name)")
        .order("updated_at", { ascending: false });

      if (cancelled) return;

      if (profileError) {
        setError(profileError.message);
        setClients([]);
        setIsLoading(false);
        return;
      }

      const clientProfiles = (profiles ?? []) as ClientProfileRow[];
      if (clientProfiles.length === 0) {
        setClients([]);
        setIsLoading(false);
        return;
      }

      const clientIds = clientProfiles.map((profile) => profile.id);

      const [sessionsResult, recoveryGraphResult] = await Promise.all([
        insforge
          .from("sessions")
          .select("id, client_id, status, started_at, completed_at, created_at, updated_at")
          .in("client_id", clientIds)
          .order("updated_at", { ascending: false }),
        insforge
          .from("recovery_graph")
          .select("id, client_id, metric_type, value, recorded_at")
          .eq("metric_type", "recovery_score")
          .in("client_id", clientIds)
          .order("recorded_at", { ascending: false }),
      ]);

      if (cancelled) return;

      if (sessionsResult.error) {
        setError(sessionsResult.error.message);
        setClients([]);
        setIsLoading(false);
        return;
      }

      if (recoveryGraphResult.error) {
        setError(recoveryGraphResult.error.message);
        setClients([]);
        setIsLoading(false);
        return;
      }

      const sessionsByClient = new Map<string, SessionRow[]>();
      for (const row of (sessionsResult.data ?? []) as SessionRow[]) {
        const existing = sessionsByClient.get(row.client_id) ?? [];
        existing.push(row);
        sessionsByClient.set(row.client_id, existing);
      }

      const recoveryScoreByClient = new Map<string, number>();
      for (const row of (recoveryGraphResult.data ?? []) as RecoveryGraphRow[]) {
        if (!recoveryScoreByClient.has(row.client_id)) {
          recoveryScoreByClient.set(row.client_id, row.value);
        }
      }

      const nextClients = buildClientList(clientProfiles, sessionsByClient, recoveryScoreByClient);
      if (!cancelled) {
        setClients(nextClients);
        setIsLoading(false);
      }
    }

    void loadClients();

    return () => {
      cancelled = true;
    };
  }, [insforge, reloadToken]);

  const sortedClients = sortClients(clients, sortMode);

  return (
    <main className="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 py-6 sm:px-6 lg:px-8">
      <section className="overflow-hidden rounded-3xl border border-emerald-100 bg-gradient-to-br from-slate-950 via-slate-900 to-emerald-950 px-6 py-8 text-white shadow-[0_24px_80px_rgba(15,23,42,0.24)] sm:px-8">
        <div className="max-w-3xl space-y-4">
          <p className="text-xs font-semibold uppercase tracking-[0.35em] text-emerald-300">
            Hydrawav3 practitioner dashboard
          </p>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Client list
          </h1>
          <p className="max-w-2xl text-sm leading-6 text-slate-300 sm:text-base">
            Review every client in the clinic, check the latest recovery score, and move into the next action without breaking flow.
          </p>
        </div>
      </section>

      <ClientListTable
        clients={sortedClients}
        sortMode={sortMode}
        onSortModeChange={setSortMode}
        isLoading={isLoading}
        error={error}
        onRetry={() => {
          setReloadToken((token) => token + 1);
        }}
      />
    </main>
  );
}
