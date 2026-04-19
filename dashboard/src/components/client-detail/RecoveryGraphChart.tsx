"use client";

import type { RecoveryGraphPoint } from "@hydrascan/shared";
import { formatBodyRegion } from "@/lib/formatters";

function bucketPoint(metricType: string) {
  if (metricType.includes("recovery_score")) return "Recovery score";
  if (metricType.includes("asymmetry")) return "Asymmetry";
  return "ROM";
}

function seriesForBucket(points: RecoveryGraphPoint[], bucket: string) {
  const filtered = points
    .filter((point) => bucketPoint(point.metricType) === bucket)
    .slice()
    .sort((a, b) => new Date(a.recordedAt).getTime() - new Date(b.recordedAt).getTime());

  return filtered.map((point) => point.value);
}

function Sparkline({
  values,
  accent,
}: {
  values: number[];
  accent: string;
}) {
  if (values.length === 0) {
    return <div className="h-20 rounded-2xl border border-dashed border-slate-200 bg-slate-50" />;
  }

  const gradientId = `spark-${accent.replace("#", "")}`;
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;
  const width = 320;
  const height = 88;
  const step = values.length > 1 ? width / (values.length - 1) : width;
  const points = values
    .map((value, index) => {
      const x = values.length === 1 ? width / 2 : index * step;
      const y = height - ((value - min) / range) * (height - 14) - 7;
      return `${x},${y}`;
    })
    .join(" ");

  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="h-24 w-full">
      <defs>
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" stopColor={accent} stopOpacity="0.22" />
          <stop offset="100%" stopColor={accent} stopOpacity="1" />
        </linearGradient>
      </defs>
      <polyline
        fill="none"
        stroke={`url(#${gradientId})`}
        strokeWidth="3"
        strokeLinejoin="round"
        strokeLinecap="round"
        points={points}
      />
      {values.map((value, index) => {
        const x = values.length === 1 ? width / 2 : index * step;
        const y = height - ((value - min) / range) * (height - 14) - 7;
        return <circle key={`${index}-${value}`} cx={x} cy={y} r="3.5" fill={accent} />;
      })}
    </svg>
  );
}

function MetricRow({
  label,
  values,
  accent,
}: {
  label: string;
  values: number[];
  accent: string;
}) {
  const latest = values.at(-1);

  return (
    <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-slate-500">{label}</p>
          <p className="mt-1 text-sm text-slate-600">
            {latest == null ? "No readings yet" : `Latest value ${Math.round(latest)}`}
          </p>
        </div>
        <div className="rounded-full bg-white px-3 py-1 text-xs font-semibold text-slate-700">
          {values.length} points
        </div>
      </div>
      <div className="mt-3">
        <Sparkline values={values} accent={accent} />
      </div>
    </div>
  );
}

export function RecoveryGraphChart({
  bodyRegion,
  dataPoints,
  isLoading,
  error,
}: {
  bodyRegion: string;
  dataPoints: RecoveryGraphPoint[];
  isLoading?: boolean;
  error?: Error | null;
}) {
  const romSeries = seriesForBucket(dataPoints, "ROM");
  const asymSeries = seriesForBucket(dataPoints, "Asymmetry");
  const scoreSeries = seriesForBucket(dataPoints, "Recovery score");

  return (
    <section className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
            Recovery graph
          </p>
          <h3 className="mt-1 text-xl font-semibold text-slate-950">
            {formatBodyRegion(bodyRegion)} over time
          </h3>
          <p className="mt-1 text-sm text-slate-600">
            ROM, asymmetry, and recovery score trend together for the selected region.
          </p>
        </div>
        <div className="rounded-full border border-slate-200 bg-slate-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-slate-600">
          Time series
        </div>
      </div>

      {isLoading ? (
        <div className="mt-5 space-y-3">
          <div className="h-28 animate-pulse rounded-2xl bg-slate-100" />
          <div className="h-28 animate-pulse rounded-2xl bg-slate-100" />
          <div className="h-28 animate-pulse rounded-2xl bg-slate-100" />
        </div>
      ) : error ? (
        <div className="mt-5 rounded-2xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-800">
          Unable to load the graph right now.
        </div>
      ) : dataPoints.length === 0 ? (
        <div className="mt-5 rounded-2xl border border-dashed border-slate-300 bg-slate-50 p-5 text-sm text-slate-600">
          This region has no recovery graph points yet. The chart will populate after the first
          assessment, session, or check-in.
        </div>
      ) : (
        <div className="mt-5 grid gap-3">
          <MetricRow label="ROM" values={romSeries} accent="#f59e0b" />
          <MetricRow label="Asymmetry" values={asymSeries} accent="#0f766e" />
          <MetricRow label="Recovery score" values={scoreSeries} accent="#16a34a" />
        </div>
      )}
    </section>
  );
}
