"use client";

import type { BodyRegion, SessionConfig } from "@hydrascan/shared";
import { formatBodyRegion, formatDuration } from "@/lib/formatters";

function MetricChip({
  label,
  value,
}: {
  label: string;
  value: string;
}) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-slate-50 px-3 py-2">
      <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">{label}</p>
      <p className="mt-1 text-sm font-semibold text-slate-950">{value}</p>
    </div>
  );
}

function FuncStack({
  title,
  values,
}: {
  title: string;
  values: string[];
}) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-3">
      <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-500">{title}</p>
      <div className="mt-2 flex flex-wrap gap-2">
        {values.map((value, index) => (
          <span
            key={`${title}-${value}-${index}`}
            className="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700"
          >
            {value}
          </span>
        ))}
      </div>
    </div>
  );
}

export function ProtocolCard({
  sessionConfig,
  bodyRegion,
  recoveryGoal,
}: {
  sessionConfig: SessionConfig;
  bodyRegion: BodyRegion;
  recoveryGoal: string;
}) {
  return (
    <section className="rounded-[2rem] border border-slate-200 bg-[linear-gradient(180deg,rgba(255,255,255,1),rgba(248,250,252,0.96))] p-5 shadow-[0_18px_60px_-34px_rgba(15,23,42,0.34)]">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-500">
            Hydrawav3 protocol
          </p>
          <h3 className="mt-1 text-2xl font-semibold text-slate-950">
            {recoveryGoal.replace("_", " ")} for {formatBodyRegion(bodyRegion)}
          </h3>
          <p className="mt-2 text-sm leading-6 text-slate-600">
            This recommendation keeps the pad sequence and thermal rhythm aligned to the current
            movement insights.
          </p>
        </div>
        <MetricChip label="Session duration" value={formatDuration(sessionConfig.totalDuration)} />
      </div>

      <div className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <MetricChip label="Sun focus" value={`Hot ${sessionConfig.pwmValues.hot.join(" / ")}`} />
        <MetricChip label="Moon focus" value={`Cold ${sessionConfig.pwmValues.cold.join(" / ")}`} />
        <MetricChip label="Vibration" value={`${sessionConfig.vibMin} to ${sessionConfig.vibMax}`} />
        <MetricChip label="LED" value={sessionConfig.led === 1 ? "On" : "Off"} />
        <MetricChip label="Hot drop" value={`${sessionConfig.hotDrop}`} />
        <MetricChip label="Cold drop" value={`${sessionConfig.coldDrop}`} />
      </div>

      <div className="mt-5 grid gap-4 lg:grid-cols-2">
        <FuncStack
          title="Left cycle sequence"
          values={sessionConfig.leftFuncs.map((value) => value.replace(/([A-Z])/g, " $1").trim())}
        />
        <FuncStack
          title="Right cycle sequence"
          values={sessionConfig.rightFuncs.map((value) => value.replace(/([A-Z])/g, " $1").trim())}
        />
      </div>

      <div className="mt-5 grid gap-3 sm:grid-cols-3">
        <MetricChip label="Cycle length" value={`${sessionConfig.edgeCycleDuration} min`} />
        <MetricChip label="Cycle count" value={String(sessionConfig.cycleRepetitions.length)} />
        <MetricChip label="Total session" value={formatDuration(sessionConfig.totalDuration)} />
      </div>
    </section>
  );
}
