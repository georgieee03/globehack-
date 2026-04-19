"use client";

import { formatBodyRegion } from "@/lib/formatters";

interface RomDeltaTableProps {
  preValues: Record<string, number>;
  postValues: Record<string, number>;
}

export function RomDeltaTable({ preValues, postValues }: RomDeltaTableProps) {
  const keys = Array.from(new Set([...Object.keys(preValues), ...Object.keys(postValues)])).sort();

  if (keys.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-4 text-sm text-slate-600">
        No ROM values were available for the re-test comparison.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-3xl border border-slate-200 bg-white">
      <table className="min-w-full divide-y divide-slate-200 text-sm">
        <thead className="bg-slate-50 text-left text-xs uppercase tracking-[0.18em] text-slate-500">
          <tr>
            <th className="px-4 py-3">Region</th>
            <th className="px-4 py-3">Pre</th>
            <th className="px-4 py-3">Post</th>
            <th className="px-4 py-3">Delta</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {keys.map((key) => {
            const pre = preValues[key] ?? 0;
            const post = postValues[key] ?? 0;
            const delta = post - pre;
            const isImprovement = delta > 0;

            return (
              <tr key={key}>
                <td className="px-4 py-3 font-medium text-slate-950">{formatBodyRegion(key)}</td>
                <td className="px-4 py-3 text-slate-600">{pre.toFixed(1)}</td>
                <td className="px-4 py-3 text-slate-600">{post.toFixed(1)}</td>
                <td className={["px-4 py-3 font-semibold", isImprovement ? "text-emerald-700" : delta < 0 ? "text-rose-700" : "text-slate-600"].join(" ")}>
                  {delta > 0 ? "+" : ""}
                  {delta.toFixed(1)}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
