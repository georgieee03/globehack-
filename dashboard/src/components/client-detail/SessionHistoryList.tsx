"use client";

import type { SessionHistoryItem } from "./types";

function RatingPill({ rating }: { rating: number | null }) {
  if (rating == null) {
    return (
      <span className="rounded-full border border-slate-200 bg-slate-50 px-2.5 py-1 text-[11px] font-semibold text-slate-500">
        No rating
      </span>
    );
  }

  const tone =
    rating >= 80
      ? "border-emerald-200 bg-emerald-50 text-emerald-800"
      : rating >= 50
        ? "border-amber-200 bg-amber-50 text-amber-800"
        : "border-rose-200 bg-rose-50 text-rose-800";

  return (
    <span className={`rounded-full border px-2.5 py-1 text-[11px] font-semibold ${tone}`}>
      {Math.round(rating)}
    </span>
  );
}

export function SessionHistoryList({
  sessions,
}: {
  sessions: SessionHistoryItem[];
}) {
  return (
    <section className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
            Session history
          </p>
          <h3 className="mt-1 text-xl font-semibold text-slate-950">
            Last three Hydrawav3 sessions
          </h3>
        </div>
        <span className="rounded-full border border-slate-200 bg-slate-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-slate-600">
          Recent context
        </span>
      </div>

      {sessions.length === 0 ? (
        <div className="mt-5 rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-5 text-sm text-slate-600">
          No prior sessions are available yet. The history will appear after the first launch.
        </div>
      ) : (
        <div className="mt-5 space-y-3">
          {sessions.map((session) => (
            <article
              key={session.id}
              className="rounded-[1.5rem] border border-slate-200 bg-slate-50 p-4"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-sm font-semibold text-slate-950">
                    {new Date(session.date).toLocaleString()}
                  </p>
                  <p className="mt-1 text-sm text-slate-600">{session.configSummary}</p>
                </div>
                <RatingPill rating={session.outcomeRating} />
              </div>
              {session.practitionerNotes ? (
                <p className="mt-3 rounded-2xl border border-white/70 bg-white/80 p-3 text-sm text-slate-600">
                  {session.practitionerNotes}
                </p>
              ) : null}
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
