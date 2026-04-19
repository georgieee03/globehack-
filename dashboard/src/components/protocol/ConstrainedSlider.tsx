"use client";

import { useId } from "react";

export function ConstrainedSlider({
  label,
  value,
  onChange,
  min,
  max,
  step = 1,
  unit,
  recommended,
  description,
}: {
  label: string;
  value: number;
  onChange: (value: number) => void;
  min: number;
  max: number;
  step?: number;
  unit?: string;
  recommended?: number;
  description?: string;
}) {
  const id = useId();
  const safeSpan = Math.max(1, max - min);
  const marker = recommended == null ? null : Math.min(100, Math.max(0, ((recommended - min) / safeSpan) * 100));

  return (
    <div className="rounded-2xl border border-slate-200 bg-white p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <label htmlFor={id} className="text-sm font-semibold text-slate-950">
            {label}
          </label>
          {description ? <p className="mt-1 text-xs leading-5 text-slate-500">{description}</p> : null}
        </div>
        <div className="rounded-full bg-slate-50 px-3 py-1 text-xs font-semibold text-slate-700">
          {value}
          {unit ? ` ${unit}` : ""}
        </div>
      </div>

      <div className="relative mt-4">
        <input
          id={id}
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(event) => onChange(Number(event.target.value))}
          className="w-full accent-slate-900"
        />
        {marker != null ? (
          <div
            className="pointer-events-none absolute top-1/2 h-5 -translate-y-1/2 border-l-2 border-dashed border-amber-500"
            style={{ left: `calc(${marker}% - 1px)` }}
          />
        ) : null}
      </div>

      <div className="mt-2 flex items-center justify-between text-[11px] font-medium uppercase tracking-[0.18em] text-slate-500">
        <span>{min}</span>
        <span>{recommended == null ? "Adjusted" : `Recommended ${recommended}`}</span>
        <span>{max}</span>
      </div>
    </div>
  );
}
