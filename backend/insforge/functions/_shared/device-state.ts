export type DeviceStatus =
  | "idle"
  | "in_session"
  | "paused"
  | "maintenance"
  | "offline";

export type HydrawavCommand = "start" | "pause" | "resume" | "stop";

export type PlayCmd = 1 | 2 | 3 | 4;

const TRANSITIONS: Record<
  DeviceStatus,
  Partial<Record<HydrawavCommand, DeviceStatus>>
> = {
  idle: {
    start: "in_session",
  },
  in_session: {
    pause: "paused",
    stop: "idle",
  },
  paused: {
    resume: "in_session",
    stop: "idle",
  },
  maintenance: {},
  offline: {},
};

const COMMAND_LABELS: Record<HydrawavCommand, string> = {
  start: "Start",
  pause: "Pause",
  resume: "Resume",
  stop: "Stop",
};

export const COMMAND_TO_PLAY_CMD: Record<HydrawavCommand, PlayCmd> = {
  start: 1,
  pause: 2,
  stop: 3,
  resume: 4,
};

export function isDeviceStatus(value: unknown): value is DeviceStatus {
  return typeof value === "string" && value in TRANSITIONS;
}

export function getNextStatus(
  currentStatus: DeviceStatus,
  command: HydrawavCommand,
): DeviceStatus | null {
  return TRANSITIONS[currentStatus][command] ?? null;
}

export function isValidTransition(
  currentStatus: DeviceStatus,
  command: HydrawavCommand,
): boolean {
  return getNextStatus(currentStatus, command) !== null;
}

export function describeInvalidTransition(
  currentStatus: DeviceStatus,
  command: HydrawavCommand,
): string {
  return `${COMMAND_LABELS[command]} is not allowed while device status is ${currentStatus}`;
}
