import type { BodyRegion } from "./client-profile.js";
import type { DeviceStatus } from "./device.js";
import type { SafeEnvelopeViolation } from "./safe-envelope.js";

export type ModalityFunc =
  | "leftColdBlue"
  | "leftHotRed"
  | "rightColdBlue"
  | "rightHotRed";

export type PlayCmd = 1 | 2 | 3 | 4;

export interface SessionConfig {
  mac: string;
  sessionCount: number;
  sessionPause: number;
  sDelay: number;
  cycle1: number;
  cycle5: number;
  edgeCycleDuration: number;
  cycleRepetitions: number[];
  cycleDurations: number[];
  cyclePauses: number[];
  pauseIntervals: number[];
  leftFuncs: ModalityFunc[];
  rightFuncs: ModalityFunc[];
  pwmValues: {
    hot: [number, number, number];
    cold: [number, number, number];
  };
  playCmd: PlayCmd;
  led: 0 | 1;
  hotDrop: number;
  coldDrop: number;
  vibMin: number;
  vibMax: number;
  totalDuration: number;
}

export type MqttCommandType = "start" | "pause" | "resume" | "stop";

export interface HydrawavAuthRequest {
  username: string;
  password: string;
}

export interface HydrawavAuthResponse {
  success: boolean;
  simulated?: boolean;
  error?: string;
}

export interface MqttCommandRequest {
  deviceId: string;
  command: MqttCommandType;
  sessionConfig?: SessionConfig;
  bodyRegion?: BodyRegion;
}

export interface MqttCommandResponse {
  success: boolean;
  simulated: boolean;
  command: MqttCommandType;
  deviceMac: string;
  newStatus: DeviceStatus;
  error?: string;
  violations?: SafeEnvelopeViolation[];
}

export interface MinimalCommandPayload {
  mac: string;
  playCmd: Exclude<PlayCmd, 1> | 1;
}
