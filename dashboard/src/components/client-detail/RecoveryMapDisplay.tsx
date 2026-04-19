"use client";

import type { BodyRegion, RecoveryMap } from "@hydrascan/shared";
import { BodyAvatar } from "./BodyAvatar";
import { formatBodyRegion } from "@/lib/formatters";

function StatusPill({
  label,
  tone,
}: {
  label: string;
  tone: "rose" | "amber" | "sky" | "emerald";
}) {
  const styles = {
    rose: "border-rose-200 bg-rose-50 text-rose-800",
    amber: "border-amber-200 bg-amber-50 text-amber-800",
    sky: "border-sky-200 bg-sky-50 text-sky-800",
    emerald: "border-emerald-200 bg-emerald-50 text-emerald-800",
  };

  return (
    <span className={`rounded-full border px-2.5 py-1 text-[11px] font-semibold ${styles[tone]}`}>
      {label}
    </span>
  );
}

function toneForSeverity(severity: number) {
  if (severity >= 8) return "rose";
  if (severity >= 5) return "amber";
  return "sky";
}

function toneForTrend(trend: RecoveryMap["highlightedRegions"][number]["trend"]) {
  if (trend === "declining") return "rose";
  if (trend === "improving") return "emerald";
  return "sky";
}

export function RecoveryMapDisplay({
  recoveryMap,
  primaryRegion,
}: {
  recoveryMap: RecoveryMap | null;
  primaryRegion?: BodyRegion | null;
}) {
  if (!recoveryMap) {
    return (
      <div className="rounded-[2rem] border border-dashed border-slate-300 bg-white p-6 text-slate-500">
        <p className="text-sm font-medium text-slate-700">Recovery map is loading.</p>
        <p className="mt-1 text-sm">
          The movement summary will appear here once the latest assessment is ready.
        </p>
      </div>
    );
  }

  return (
    <section className="space-y-5">
      <BodyAvatar highlightedRegions={recoveryMap.highlightedRegions} primaryRegion={primaryRegion} />

      <div className="grid gap-4 xl:grid-cols-2">
        {recoveryMap.highlightedRegions.map((region) => (
          <article
            key={region.region}
            className="rounded-[1.75rem] border border-slate-200 bg-white p-5 shadow-[0_18px_50px_-32px_rgba(15,23,42,0.3)]"
          >
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
                  {formatBodyRegion(region.region)}
                </p>
                <h3 className="mt-1 text-lg font-semibold text-slate-950">
                  Severity {region.severity}/10
                </h3>
              </div>
              <div className="flex flex-wrap gap-2">
                <StatusPill label={region.signalType} tone={toneForSeverity(region.severity)} />
                <StatusPill
                  label={region.trend ?? "stable"}
                  tone={toneForTrend(region.trend)}
                />
                {region.asymmetryFlag ? <StatusPill label="Asymmetry" tone="amber" /> : null}
              </div>
            </div>

            <div className="mt-4 grid gap-4 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center">
              <div className="space-y-2">
                <div className="h-2 rounded-full bg-slate-100">
                  <div
                    className="h-2 rounded-full bg-gradient-to-r from-amber-400 to-rose-500"
                    style={{ width: `${Math.min(100, Math.max(10, region.severity * 10))}%` }}
                  />
                </div>
                <div className="grid grid-cols-2 gap-3 text-sm text-slate-600">
                  <div className="rounded-2xl bg-slate-50 p-3">
                    <p className="text-[11px] uppercase tracking-[0.18em] text-slate-500">ROM delta</p>
                    <p className="mt-1 font-medium text-slate-950">
                      {region.romDelta == null ? "Not yet compared" : `${region.romDelta > 0 ? "+" : ""}${region.romDelta} deg`}
                    </p>
                  </div>
                  <div className="rounded-2xl bg-slate-50 p-3">
                    <p className="text-[11px] uppercase tracking-[0.18em] text-slate-500">
                      Compensation
                    </p>
                    <p className="mt-1 font-medium text-slate-950">
                      {region.compensationHint ?? "No compensation hint"}
                    </p>
                  </div>
                </div>
              </div>
              <div className="rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
                <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                  Region note
                </p>
                <p className="mt-1 max-w-xs">
                  {region.trend === "declining"
                    ? "Movement is trending down, so this region should stay in the practitioner's focus."
                    : region.trend === "improving"
                      ? "Movement is improving and may support a lighter follow-up emphasis."
                      : "Movement is holding steady and still benefits from balanced support."}
                </p>
              </div>
            </div>
          </article>
        ))}
      </div>

      <div className="grid gap-4 xl:grid-cols-[1.2fr_0.8fr]">
        <article className="rounded-[1.75rem] border border-slate-200 bg-white p-5 shadow-[0_18px_50px_-32px_rgba(15,23,42,0.3)]">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
            Recovery summary
          </p>
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <span className="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-sm font-medium text-emerald-800">
              Suggested goal: {recoveryMap.suggestedGoal.replace("_", " ")}
            </span>
            <span className="rounded-full border border-slate-200 bg-slate-50 px-3 py-1 text-sm font-medium text-slate-700">
              Generated {new Date(recoveryMap.generatedAt).toLocaleString()}
            </span>
          </div>
          <p className="mt-4 text-sm leading-6 text-slate-600">
            The summary blends current movement insights, ROM change, asymmetry, and adjacent
            compensation patterns to give a fast view of where Hydrawav3 support should begin.
          </p>
        </article>

        {recoveryMap.wearableContext ? (
          <article className="rounded-[1.75rem] border border-slate-200 bg-white p-5 shadow-[0_18px_50px_-32px_rgba(15,23,42,0.3)]">
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
              Wearable context
            </p>
            <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
              <div className="rounded-2xl bg-slate-50 p-3">
                <dt className="text-[11px] uppercase tracking-[0.18em] text-slate-500">HRV</dt>
                <dd className="mt-1 font-medium text-slate-950">{recoveryMap.wearableContext.hrv}</dd>
              </div>
              <div className="rounded-2xl bg-slate-50 p-3">
                <dt className="text-[11px] uppercase tracking-[0.18em] text-slate-500">Strain</dt>
                <dd className="mt-1 font-medium text-slate-950">{recoveryMap.wearableContext.strain}</dd>
              </div>
              <div className="rounded-2xl bg-slate-50 p-3">
                <dt className="text-[11px] uppercase tracking-[0.18em] text-slate-500">Sleep</dt>
                <dd className="mt-1 font-medium text-slate-950">
                  {recoveryMap.wearableContext.sleepScore}/100
                </dd>
              </div>
              <div className="rounded-2xl bg-slate-50 p-3">
                <dt className="text-[11px] uppercase tracking-[0.18em] text-slate-500">Last sync</dt>
                <dd className="mt-1 font-medium text-slate-950">
                  {new Date(recoveryMap.wearableContext.lastSync).toLocaleString()}
                </dd>
              </div>
            </dl>
          </article>
        ) : null}
      </div>
    </section>
  );
}
