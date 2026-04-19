"use client";

import Link from "next/link";
import type { ClientListItem } from "./types";
import { formatClientDate, formatClientRegions, formatClientScore } from "./utils";

interface ClientRowProps {
  client: ClientListItem;
}

function StatusBadge({ children }: { children: string }) {
  return (
    <span className="inline-flex items-center rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-800 ring-1 ring-inset ring-emerald-200">
      {children}
    </span>
  );
}

function ScoreBadge({ score }: { score: number | null }) {
  const numericScore = score ?? null;
  const tone =
    numericScore == null
      ? "bg-slate-100 text-slate-700 ring-slate-200"
      : numericScore >= 70
        ? "bg-emerald-50 text-emerald-800 ring-emerald-200"
        : numericScore >= 40
          ? "bg-amber-50 text-amber-800 ring-amber-200"
          : "bg-rose-50 text-rose-800 ring-rose-200";

  return (
    <span className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold ring-1 ring-inset ${tone}`}>
      {formatClientScore(score)}
    </span>
  );
}

export function ClientRow({ client }: ClientRowProps) {
  const regions = formatClientRegions(client.primaryRegions);

  return (
    <Link
      href={`/clients/${client.id}`}
      className="group block rounded-3xl border border-slate-200 bg-white p-4 shadow-sm transition duration-200 hover:-translate-y-0.5 hover:border-emerald-300 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:ring-offset-2"
      prefetch
    >
      <div className="flex flex-col gap-5 lg:flex-row lg:items-center lg:justify-between">
        <div className="space-y-3">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">
              Client
            </p>
            <h3 className="mt-1 text-xl font-semibold text-slate-950 transition group-hover:text-emerald-800">
              {client.fullName}
            </h3>
          </div>

          <div className="flex flex-wrap gap-2">
            {regions.length > 0 ? (
              regions.map((region) => (
                <span
                  key={region}
                  className="rounded-full bg-slate-100 px-3 py-1 text-xs font-medium text-slate-700"
                >
                  {region}
                </span>
              ))
            ) : (
              <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-medium text-slate-700">
                Primary regions pending
              </span>
            )}
          </div>
        </div>

        <div className="grid gap-3 sm:grid-cols-3 lg:min-w-[32rem]">
          <div className="rounded-2xl bg-slate-50 px-4 py-3">
            <p className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">
              Recovery score
            </p>
            <div className="mt-2">
              <ScoreBadge score={client.latestRecoveryScore} />
            </div>
          </div>

          <div className="rounded-2xl bg-slate-50 px-4 py-3">
            <p className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">
              Most recent session
            </p>
            <p className="mt-2 text-sm font-medium text-slate-900">
              {formatClientDate(client.mostRecentSessionDate)}
            </p>
          </div>

          <div className="rounded-2xl bg-slate-50 px-4 py-3">
            <p className="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">
              Next session
            </p>
            <div className="mt-2">
              <StatusBadge>{client.nextSessionStatus}</StatusBadge>
            </div>
          </div>
        </div>
      </div>
    </Link>
  );
}
