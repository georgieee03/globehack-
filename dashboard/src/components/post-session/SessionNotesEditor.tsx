"use client";

import { useState } from "react";
import { useSupabase } from "@/hooks/useSupabase";

interface SessionNotesEditorProps {
  sessionId: string;
  initialNotes?: string | null;
  onSaved?: (notes: string) => void;
}

export function SessionNotesEditor({ sessionId, initialNotes, onSaved }: SessionNotesEditorProps) {
  const supabase = useSupabase();
  const [notes, setNotes] = useState(initialNotes ?? "");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function handleSave() {
    setSaving(true);
    setMessage(null);

    try {
      const { error } = await supabase
        .from("sessions")
        .update({ practitioner_notes: notes })
        .eq("id", sessionId);

      if (error) {
        throw new Error(error.message);
      }

      onSaved?.(notes);
      setMessage("Session notes saved.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Unable to save notes.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="rounded-[2rem] border border-slate-200 bg-white p-5 shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-slate-500">Session notes</p>
          <h3 className="mt-2 text-xl font-semibold text-slate-950">Practitioner observations</h3>
        </div>
        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className="rounded-full bg-slate-950 px-4 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
        >
          {saving ? "Saving..." : "Save notes"}
        </button>
      </div>

      <textarea
        value={notes}
        onChange={(event) => setNotes(event.target.value)}
        rows={6}
        className="mt-4 w-full rounded-3xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-950 outline-none transition placeholder:text-slate-400 focus:border-slate-400"
        placeholder="Record wellness observations, adjustments, and follow-up plans."
      />

      {message ? (
        <p className="mt-3 text-sm text-slate-600">{message}</p>
      ) : (
        <p className="mt-3 text-sm text-slate-500">Notes are stored on the session record for future review.</p>
      )}
    </section>
  );
}
