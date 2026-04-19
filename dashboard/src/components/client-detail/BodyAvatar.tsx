"use client";

import type { BodyRegion, HighlightedRegion } from "@hydrascan/shared";
import { formatBodyRegion } from "@/lib/formatters";

const LEFT_REGIONS: BodyRegion[] = [
  "left_shoulder",
  "left_arm",
  "left_hip",
  "left_knee",
  "left_calf",
  "left_foot",
];

const RIGHT_REGIONS: BodyRegion[] = [
  "right_shoulder",
  "right_arm",
  "right_hip",
  "right_knee",
  "right_calf",
  "right_foot",
];

const CENTER_REGIONS: BodyRegion[] = ["neck", "upper_back", "lower_back"];

function regionTone(severity: number) {
  if (severity >= 8) return "from-rose-500 to-orange-500";
  if (severity >= 5) return "from-amber-400 to-amber-600";
  return "from-cyan-400 to-sky-600";
}

function regionWeight(severity: number) {
  if (severity >= 8) return "shadow-[0_0_0_1px_rgba(244,63,94,0.35),0_0_30px_rgba(251,146,60,0.25)]";
  if (severity >= 5) return "shadow-[0_0_0_1px_rgba(245,158,11,0.28),0_0_24px_rgba(245,158,11,0.18)]";
  return "shadow-[0_0_0_1px_rgba(14,165,233,0.28),0_0_20px_rgba(14,165,233,0.16)]";
}

function RegionColumn({
  title,
  regions,
  highlighted,
}: {
  title: string;
  regions: BodyRegion[];
  highlighted: HighlightedRegion[];
}) {
  return (
    <div className="space-y-2">
      <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-500">{title}</p>
      <div className="space-y-2">
        {regions.map((region) => {
          const item = highlighted.find((entry) => entry.region === region);
          const severity = item?.severity ?? 0;
          const active = Boolean(item);

          return (
            <div
              key={region}
              className={[
                "rounded-2xl border px-3 py-2 text-xs transition",
                active
                  ? `border-transparent bg-gradient-to-r ${regionTone(severity)} text-white ${regionWeight(severity)}`
                  : "border-slate-200 bg-white text-slate-500",
              ].join(" ")}
            >
              <div className="flex items-center justify-between gap-2">
                <span className="font-medium">{formatBodyRegion(region)}</span>
                <span className="text-[10px] uppercase tracking-[0.18em]">
                  {active ? `S${severity}` : "Calm"}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function BodyAvatar({
  highlightedRegions,
  primaryRegion,
}: {
  highlightedRegions: HighlightedRegion[];
  primaryRegion?: BodyRegion | null;
}) {
  const primary = highlightedRegions.find((region) => region.region === primaryRegion) ?? highlightedRegions[0];

  return (
    <div className="rounded-[2rem] border border-slate-200 bg-gradient-to-b from-white via-white to-slate-50 p-5 shadow-[0_24px_80px_-40px_rgba(15,23,42,0.35)]">
      <div className="mb-4 flex items-center justify-between">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">Body map</p>
          <h3 className="text-lg font-semibold text-slate-950">Highlighted movement regions</h3>
        </div>
        {primary ? (
          <div className="rounded-full border border-amber-200 bg-amber-50 px-3 py-1 text-xs font-medium text-amber-800">
            Primary focus: {formatBodyRegion(primary.region)}
          </div>
        ) : null}
      </div>

      <div className="grid gap-4 lg:grid-cols-[1fr_auto_1fr]">
        <RegionColumn title="Left side" regions={LEFT_REGIONS} highlighted={highlightedRegions} />

        <div className="relative flex min-h-[22rem] items-center justify-center rounded-[2rem] border border-slate-200 bg-[radial-gradient(circle_at_top,rgba(15,23,42,0.06),rgba(255,255,255,0)_55%),linear-gradient(180deg,rgba(255,255,255,0.92),rgba(248,250,252,1))] p-6">
          <div className="absolute inset-x-1/2 top-5 h-10 w-10 -translate-x-1/2 rounded-full border border-slate-300 bg-gradient-to-b from-slate-100 to-slate-300" />
          <div className="absolute inset-x-1/2 top-16 h-28 w-24 -translate-x-1/2 rounded-[3rem] border border-slate-300 bg-gradient-to-b from-slate-50 to-slate-200" />
          <div className="absolute inset-x-1/2 top-40 h-20 w-28 -translate-x-1/2 rounded-[2rem] border border-slate-300 bg-gradient-to-b from-slate-100 to-slate-200" />
          <div className="absolute inset-x-1/2 bottom-16 h-28 w-16 -translate-x-1/2 rounded-[2rem] border border-slate-300 bg-gradient-to-b from-slate-100 to-slate-200" />
          <div className="absolute inset-x-0 bottom-4 text-center">
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
              Hydrawav3 body avatar
            </p>
            <p className="mt-1 text-sm text-slate-600">
              Warmth is centered on the primary region while adjacent support areas stay visible.
            </p>
          </div>
        </div>

        <RegionColumn title="Right side" regions={RIGHT_REGIONS} highlighted={highlightedRegions} />
      </div>

      <div className="mt-4 grid gap-2 sm:grid-cols-3">
        {CENTER_REGIONS.map((region) => {
          const item = highlightedRegions.find((entry) => entry.region === region);
          return (
            <div
              key={region}
              className={[
                "rounded-2xl border px-3 py-2 text-sm",
                item
                  ? "border-sky-200 bg-sky-50 text-sky-900"
                  : "border-slate-200 bg-white text-slate-500",
              ].join(" ")}
            >
              <p className="text-[11px] font-semibold uppercase tracking-[0.18em]">Center line</p>
              <p className="mt-1 font-medium">{formatBodyRegion(region)}</p>
            </div>
          );
        })}
      </div>
    </div>
  );
}
