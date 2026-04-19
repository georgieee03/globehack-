"use client";

import type { DeviceRecord } from "@hydrascan/shared";
import { DeviceCard } from "./DeviceCard";

interface DeviceListProps {
  devices: DeviceRecord[];
  selectedDeviceId: string | null;
  onSelectDevice: (device: DeviceRecord) => void;
  emptyLabel?: string;
}

export function DeviceList({
  devices,
  selectedDeviceId,
  onSelectDevice,
  emptyLabel = "No devices are currently available for launch.",
}: DeviceListProps) {
  if (devices.length === 0) {
    return (
      <div className="rounded-3xl border border-dashed border-slate-300 bg-white/70 p-6 text-sm text-slate-600">
        {emptyLabel}
      </div>
    );
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      {devices.map((device) => (
        <DeviceCard
          key={device.id}
          device={device}
          selected={selectedDeviceId === device.id}
          onSelect={onSelectDevice}
        />
      ))}
    </div>
  );
}
