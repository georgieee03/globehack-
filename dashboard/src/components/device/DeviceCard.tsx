"use client";

import type { DeviceRecord } from "@hydrascan/shared";

interface DeviceCardProps {
  device: DeviceRecord;
  selected?: boolean;
  disabled?: boolean;
  onSelect?: (device: DeviceRecord) => void;
}

function statusStyles(status: DeviceRecord["status"]) {
  switch (status) {
    case "idle":
      return "border-emerald-200 bg-emerald-50 text-emerald-900";
    case "in_session":
      return "border-sky-200 bg-sky-50 text-sky-900";
    case "paused":
      return "border-amber-200 bg-amber-50 text-amber-900";
    case "maintenance":
      return "border-stone-200 bg-stone-100 text-stone-700";
    case "offline":
      return "border-rose-200 bg-rose-50 text-rose-900";
    default:
      return "border-slate-200 bg-slate-50 text-slate-700";
  }
}

function statusLabel(status: DeviceRecord["status"]) {
  switch (status) {
    case "idle":
      return "Available";
    case "in_session":
      return "In session";
    case "paused":
      return "Paused";
    case "maintenance":
      return "Maintenance";
    case "offline":
      return "Offline";
    default:
      return status;
  }
}

export function DeviceCard({
  device,
  selected = false,
  disabled = false,
  onSelect,
}: DeviceCardProps) {
  const selectable = device.status === "idle" && !disabled;

  return (
    <button
      type="button"
      onClick={() => selectable && onSelect?.(device)}
      disabled={!selectable}
      className={[
        "group w-full rounded-3xl border p-4 text-left transition",
        selected
          ? "border-slate-950 bg-slate-950 text-white shadow-lg shadow-slate-950/10"
          : "border-slate-200 bg-white hover:border-slate-300 hover:shadow-md",
        !selectable ? "cursor-not-allowed opacity-70" : "",
      ].join(" ")}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className={["text-base font-semibold", selected ? "text-white" : "text-slate-950"].join(" ")}>
            {device.label}
          </p>
          <p className={["mt-1 text-sm", selected ? "text-slate-200" : "text-slate-500"].join(" ")}>
            Hydrawav3 in {device.room ?? "an unassigned room"}
          </p>
        </div>
        <span
          className={[
            "rounded-full border px-3 py-1 text-xs font-medium uppercase tracking-[0.18em]",
            selected ? "border-white/20 bg-white/10 text-white" : statusStyles(device.status),
          ].join(" ")}
        >
          {statusLabel(device.status)}
        </span>
      </div>

      <div className={["mt-4 grid gap-2 text-sm", selected ? "text-slate-100" : "text-slate-600"].join(" ")}>
        <div className="flex items-center justify-between gap-3">
          <span>MAC</span>
          <span className="font-medium">{device.device_mac}</span>
        </div>
        <div className="flex items-center justify-between gap-3">
          <span>Last session</span>
          <span className="font-medium">{device.last_session_id ?? "None yet"}</span>
        </div>
      </div>

      {!selectable ? (
        <p className={["mt-4 text-xs", selected ? "text-slate-200" : "text-slate-500"].join(" ")}>
          This device is not selectable until it returns to idle.
        </p>
      ) : (
        <p className={["mt-4 text-xs font-medium", selected ? "text-slate-100" : "text-slate-500"].join(" ")}>
          Ready to launch a Hydrawav3 session.
        </p>
      )}
    </button>
  );
}
