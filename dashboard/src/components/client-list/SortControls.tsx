"use client";

import { toWellnessText } from "./utils";
import type { ClientListSortMode } from "./types";

interface SortControlsProps {
  value: ClientListSortMode;
  onChange: (value: ClientListSortMode) => void;
}

export function SortControls({ value, onChange }: SortControlsProps) {
  const buttons: Array<{ label: string; value: ClientListSortMode }> = [
    { label: "Most recent activity", value: "recent" },
    { label: "Recovery score", value: "score" },
  ];

  return (
    <div className="flex flex-col gap-3 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm sm:flex-row sm:items-center sm:justify-between">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.3em] text-slate-500">
          {toWellnessText("Sort clients")}
        </p>
        <p className="mt-1 text-sm text-slate-600">
          Move between recent activity and the clients who need attention first.
        </p>
      </div>

      <div className="inline-flex rounded-2xl bg-slate-100 p-1">
        {buttons.map((button) => {
          const active = button.value === value;

          return (
            <button
              key={button.value}
              type="button"
              onClick={() => onChange(button.value)}
              className={[
                "rounded-xl px-4 py-2 text-sm font-medium transition",
                active
                  ? "bg-slate-950 text-white shadow-sm"
                  : "text-slate-600 hover:bg-white hover:text-slate-900",
              ].join(" ")}
              aria-pressed={active}
            >
              {button.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
