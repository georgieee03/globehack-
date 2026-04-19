"use client";

import { useEffect, useState } from "react";
import { formatDuration } from "@/lib/formatters";

interface ElapsedTimerProps {
  startedAt: string | null;
  status: "active" | "paused" | "completed" | "pending" | "cancelled" | "error";
}

function elapsedSeconds(startedAt: string | null) {
  if (!startedAt) return 0;
  const started = new Date(startedAt).getTime();
  if (Number.isNaN(started)) return 0;
  return Math.max(0, Math.floor((Date.now() - started) / 1000));
}

export function ElapsedTimer({ startedAt, status }: ElapsedTimerProps) {
  const [seconds, setSeconds] = useState(() => elapsedSeconds(startedAt));

  useEffect(() => {
    setSeconds(elapsedSeconds(startedAt));
  }, [startedAt]);

  useEffect(() => {
    if (status !== "active" || !startedAt) {
      return;
    }

    const timer = setInterval(() => {
      setSeconds(elapsedSeconds(startedAt));
    }, 1000);

    return () => clearInterval(timer);
  }, [startedAt, status]);

  return (
    <div className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
      <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Elapsed</p>
      <p className="mt-1 text-2xl font-semibold text-slate-950">{formatDuration(seconds)}</p>
    </div>
  );
}
