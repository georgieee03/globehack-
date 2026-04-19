"use client";

import { ClientRow } from "./ClientRow";
import { ClientListSkeleton } from "./ClientListSkeleton";
import { SortControls } from "./SortControls";
import { toWellnessText } from "./utils";
import type { ClientListItem, ClientListSortMode } from "./types";

interface ClientListTableProps {
  clients: ClientListItem[];
  sortMode: ClientListSortMode;
  onSortModeChange: (value: ClientListSortMode) => void;
  isLoading: boolean;
  error: string | null;
  onRetry: () => void;
}

export function ClientListTable({
  clients,
  sortMode,
  onSortModeChange,
  isLoading,
  error,
  onRetry,
}: ClientListTableProps) {
  return (
    <section className="space-y-4">
      <SortControls value={sortMode} onChange={onSortModeChange} />

      <div className="flex items-center justify-between px-1">
        <p className="text-sm text-slate-600">
          {isLoading
            ? "Loading client records"
            : `${clients.length} ${clients.length === 1 ? "client" : "clients"} ready for review`}
        </p>
        <p className="text-xs font-medium uppercase tracking-[0.24em] text-slate-400">
          {toWellnessText("Supports a focused clinic workflow")}
        </p>
      </div>

      {error ? (
        <div className="rounded-3xl border border-rose-200 bg-rose-50 p-5 text-rose-900">
          <p className="text-sm font-semibold">Client list could not load.</p>
          <p className="mt-2 text-sm text-rose-800">{error}</p>
          <button
            type="button"
            onClick={onRetry}
            className="mt-4 inline-flex rounded-xl bg-rose-900 px-4 py-2 text-sm font-semibold text-white transition hover:bg-rose-800"
          >
            Try again
          </button>
        </div>
      ) : isLoading ? (
        <ClientListSkeleton />
      ) : clients.length === 0 ? (
        <div className="rounded-3xl border border-dashed border-slate-300 bg-white px-6 py-12 text-center shadow-sm">
          <p className="text-lg font-semibold text-slate-950">No clients found</p>
          <p className="mx-auto mt-2 max-w-xl text-sm leading-6 text-slate-600">
            Once client profiles are available in this clinic, they will appear here with their latest recovery score and next action.
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {clients.map((client) => (
            <ClientRow key={client.id} client={client} />
          ))}
        </div>
      )}
    </section>
  );
}
