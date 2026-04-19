"use client";

import type { ReactNode } from "react";

interface SessionStatusDisplayProps {
  status: string;
  deviceLabel: string;
  lastUpdated?: string | null;
  isRetestMode?: boolean;
  elapsedDisplay?: ReactNode;
}

function statusTone(status: string) {
  switch (status) {
    case "active":
      return "bg-sky-50 text-sky-900 border-sky-200";
    case "paused":
      return "bg-amber-50 text-amber-900 border-amber-200";
    case "completed":
      return "bg-emerald-50 text-emerald-900 border-emerald-200";
    default:
      return "bg-slate-50 text-slate-800 border-slate-200";
  }
}

export function SessionStatusDisplay({
  status,
  deviceLabel,
  lastUpdated,
  isRetestMode = false,
  elapsedDisplay,
}: SessionStatusDisplayProps) {
  return (
    <div className="grid gap-4 rounded-3xl border border-slate-200 bg-white p-5 shadow-sm md:grid-cols-[1.5fr_1fr]">
      <div>
        <div className="flex flex-wrap items-center gap-3">
          <span className={["rounded-full border px-3 py-1 text-xs font-medium uppercase tracking-[0.18em]", statusTone(status)].join(" ")}>
            {status}
          </span>
          {isRetestMode ? (
            <span className="rounded-full border border-amber-200 bg-amber-50 px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-amber-800">
              Re-test capture mode
            </span>
          ) : null}
        </div>

        <h2 className="mt-4 text-2xl font-semibold text-slate-950">Hydrawav3 session control</h2>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
          {deviceLabel
            ? `The current session is running on ${deviceLabel}. Use the controls below to pause, resume, or stop the session.`
            : "Select an idle Hydrawav3 device and launch the session to begin live control."}
        </p>
      </div>

      <div className="rounded-2xl border border-slate-100 bg-slate-50 p-4">
        <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Device</p>
        <p className="mt-1 text-lg font-semibold text-slate-950">{deviceLabel || "No device selected"}</p>
        {lastUpdated ? <p className="mt-3 text-sm text-slate-600">Realtime update {lastUpdated}</p> : null}
        {elapsedDisplay ? <div className="mt-4">{elapsedDisplay}</div> : null}
      </div>
    </div>
  );
}
