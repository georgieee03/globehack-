import type { UserRecord } from "./user.js";

export type DeviceStatus =
  | "idle"
  | "in_session"
  | "paused"
  | "maintenance"
  | "offline";

export type DeviceCommand =
  | "start"
  | "pause"
  | "resume"
  | "stop"
  | "maintenance"
  | "clear_maintenance";

export interface DeviceRecord {
  id: string;
  clinic_id: string;
  device_mac: string;
  label: string;
  room: string | null;
  assigned_practitioner: UserRecord["id"] | null;
  status: DeviceStatus;
  last_session_id: string | null;
  firmware: string | null;
  created_at: string;
  updated_at: string;
}
