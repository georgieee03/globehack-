import type { DeviceCommand, DeviceStatus } from "../types/device.js";

const TRANSITIONS: Record<
  DeviceStatus,
  Partial<Record<DeviceCommand, DeviceStatus>>
> = {
  idle: {
    start: "in_session",
    maintenance: "maintenance",
  },
  in_session: {
    pause: "paused",
    stop: "idle",
    maintenance: "maintenance",
  },
  paused: {
    resume: "in_session",
    stop: "idle",
    maintenance: "maintenance",
  },
  maintenance: {
    clear_maintenance: "idle",
    maintenance: "maintenance",
  },
  offline: {
    maintenance: "maintenance",
  },
};

export function getNextStatus(
  currentStatus: DeviceStatus,
  command: DeviceCommand,
): DeviceStatus | null {
  return TRANSITIONS[currentStatus][command] ?? null;
}

export function isValidTransition(
  currentStatus: DeviceStatus,
  command: DeviceCommand,
): boolean {
  return getNextStatus(currentStatus, command) !== null;
}
