"use client";

import type { AssessmentRecord, SessionRecord } from "@hydrascan/shared";
import { formatBodyRegion } from "@/lib/formatters";
import { RomDeltaTable } from "./RomDeltaTable";

interface RetestComparisonProps {
  session: SessionRecord;
  assessment: AssessmentRecord | null;
  onRetest: () => void;
}

function recordMap(value: unknown): Record<string, number> {
  return value && typeof value === "object" ? (value as Record<string, number>) : {};
}

export function RetestComparison({ session, assessment, onRetest }: RetestComparisonProps) {
  const preRom = recordMap(assessment?.rom_values);
  const retestValues = session.retest_values as Record<string, unknown> | null;
  const outcomeValues = session.outcome as Record<string, unknown> | null;
  const postRom = recordMap(retestValues?.rom_values ?? outcomeValues?.rom_values);
  const preAsymmetry = recordMap(assessment?.asymmetry_scores);
  const postAsymmetry = recordMap(retestValues?.asymmetry_scores ?? outcomeValues?.asymmetry_scores);
  const preQuality = recordMap(assessment?.movement_quality_scores);
  const postQuality = recordMap(retestValues?.movement_quality_scores ?? outcomeValues?.movement_quality_scores);

  const targetRegions = assessment?.body_zones && typeof assessment.body_zones === "object"
    ? Object.keys(assessment.body_zones as Record<string, unknown>)
    : [];

  return (
    <section className="space-y-4">
      <div className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Re-test</p>
            <h2 className="mt-2 text-2xl font-semibold text-slate-950">Pre and post movement insight</h2>
          </div>
          <button
            type="button"
            onClick={onRetest}
            className="rounded-full bg-slate-950 px-4 py-2 text-sm font-medium text-white"
          >
            Re-Test
          </button>
        </div>

        <p className="mt-3 text-sm leading-6 text-slate-600">
          Compare the last assessment with the completed session to review ROM, asymmetry, and movement quality changes before you finish the visit.
        </p>

        {targetRegions.length > 0 ? (
          <div className="mt-4 rounded-2xl bg-slate-50 p-4 text-sm text-slate-700">
            <p className="text-xs uppercase tracking-[0.18em] text-slate-500">Primary regions</p>
            <p className="mt-2">{targetRegions.map((region) => formatBodyRegion(region)).join(", ")}</p>
          </div>
        ) : null}
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="rounded-3xl border border-slate-200 bg-white p-4 shadow-sm">
          <p className="text-xs uppercase tracking-[0.18em] text-slate-500">ROM</p>
          <p className="mt-2 text-lg font-semibold text-slate-950">Movement range</p>
          <p className="mt-2 text-sm text-slate-600">Positive deltas are highlighted as improvements in the table below.</p>
        </div>
        <div className="rounded-3xl border border-slate-200 bg-white p-4 shadow-sm">
          <p className="text-xs uppercase tracking-[0.18em] text-slate-500">Asymmetry</p>
          <p className="mt-2 text-lg font-semibold text-slate-950">{Object.keys(preAsymmetry).length || Object.keys(postAsymmetry).length ? "Tracked by region" : "No asymmetry data"}</p>
          <p className="mt-2 text-sm text-slate-600">Review whether the Hydrawav3 session reduced imbalance across the targeted regions.</p>
        </div>
        <div className="rounded-3xl border border-slate-200 bg-white p-4 shadow-sm">
          <p className="text-xs uppercase tracking-[0.18em] text-slate-500">Movement quality</p>
          <p className="mt-2 text-lg font-semibold text-slate-950">{Object.keys(preQuality).length || Object.keys(postQuality).length ? "Tracked by region" : "No movement quality data"}</p>
          <p className="mt-2 text-sm text-slate-600">Capture notes and observations immediately while the session context is fresh.</p>
        </div>
      </div>

      <RomDeltaTable preValues={preRom} postValues={postRom} />
    </section>
  );
}
