import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/cors.ts";
import {
  describeInvalidTransition,
  getNextStatus,
  isDeviceStatus,
  type DeviceStatus,
  type HydrawavCommand,
} from "../_shared/device-state.ts";
import {
  buildMqttPayload,
  isBodyRegion,
  parseSessionConfig,
  type BodyRegion,
  type SessionConfigInput,
  validateSafeEnvelope,
} from "../_shared/safe-envelope.ts";
import {
  createServiceRoleClient,
  getHydrawavApiBaseUrl,
  HttpError,
  isSimulationMode,
  requireAuthenticatedUser,
  requireRole,
  toAuthorizationHeader,
} from "../_shared/supabase-client.ts";

interface DeviceRecord {
  id: string;
  clinic_id: string;
  device_mac: string;
  status: DeviceStatus;
}

interface TokenRecord {
  access_token: string | null;
}

interface MqttCommandRequest {
  deviceId: string;
  command: HydrawavCommand;
  sessionConfig?: SessionConfigInput;
  bodyRegion?: BodyRegion;
}

const COMMANDS = ["start", "pause", "resume", "stop"] as const;
const HYDRAWAV_TOPIC = "HydraWav3Pro/config";
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseMqttCommandRequest(value: unknown): MqttCommandRequest {
  if (!isRecord(value)) {
    throw new HttpError(400, "Request body must be a JSON object");
  }

  const deviceId = typeof value.deviceId === "string" ? value.deviceId.trim() : "";
  const command = typeof value.command === "string"
    ? value.command.trim().toLowerCase()
    : "";
  const errors: string[] = [];

  if (!deviceId) {
    errors.push("deviceId is required");
  } else if (!UUID_PATTERN.test(deviceId)) {
    errors.push("deviceId must be a UUID");
  }

  if (!(COMMANDS as readonly string[]).includes(command)) {
    errors.push("command must be one of start, pause, resume, or stop");
  }

  let bodyRegion: BodyRegion | undefined;
  if (typeof value.bodyRegion !== "undefined") {
    if (!isBodyRegion(value.bodyRegion)) {
      errors.push("bodyRegion is not a supported BodyRegion value");
    } else {
      bodyRegion = value.bodyRegion;
    }
  }

  let sessionConfig: SessionConfigInput | undefined;
  if (command === "start") {
    const parsedConfig = parseSessionConfig(value.sessionConfig);
    if (!parsedConfig.ok) {
      errors.push(...parsedConfig.errors);
    } else {
      sessionConfig = parsedConfig.value;
    }
  }

  if (errors.length > 0) {
    throw new HttpError(400, "Invalid MQTT command request", {
      details: errors,
    });
  }

  return {
    deviceId,
    command: command as HydrawavCommand,
    bodyRegion,
    sessionConfig,
  };
}

async function fetchDevice(
  supabase: ReturnType<typeof createServiceRoleClient>,
  clinicId: string,
  deviceId: string,
): Promise<DeviceRecord> {
  const { data, error } = await supabase
    .from("devices")
    .select("id, clinic_id, device_mac, status")
    .eq("id", deviceId)
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load device", {
      detail: error.message,
    });
  }

  if (!data) {
    throw new HttpError(404, "Device not found");
  }

  if (!isDeviceStatus(data.status)) {
    throw new HttpError(500, "Device record contains an unsupported status", {
      status: data.status,
    });
  }

  return data as DeviceRecord;
}

async function fetchClinicToken(
  supabase: ReturnType<typeof createServiceRoleClient>,
  clinicId: string,
): Promise<TokenRecord> {
  const { data, error } = await supabase
    .from("clinic_hw_tokens")
    .select("access_token")
    .eq("clinic_id", clinicId)
    .maybeSingle();

  if (error) {
    throw new HttpError(500, "Failed to load clinic Hydrawav credentials", {
      detail: error.message,
    });
  }

  if (!data?.access_token) {
    throw new HttpError(
      401,
      "No Hydrawav3 credentials are configured for this clinic",
    );
  }

  return data as TokenRecord;
}

async function updateDeviceStatus(
  supabase: ReturnType<typeof createServiceRoleClient>,
  deviceId: string,
  clinicId: string,
  newStatus: DeviceStatus,
): Promise<void> {
  const { error } = await supabase
    .from("devices")
    .update({
      status: newStatus,
      updated_at: new Date().toISOString(),
    })
    .eq("id", deviceId)
    .eq("clinic_id", clinicId);

  if (error) {
    throw new HttpError(500, "Failed to update device status", {
      detail: error.message,
    });
  }
}

async function insertAuditLog(
  supabase: ReturnType<typeof createServiceRoleClient>,
  options: {
    clinicId: string;
    deviceId: string;
    command: HydrawavCommand;
    payload: Record<string, unknown>;
    mqttResponseStatus?: number | null;
    simulated: boolean;
    errorDetails?: string | null;
  },
): Promise<void> {
  const { error } = await supabase.from("mqtt_command_log").insert({
    clinic_id: options.clinicId,
    device_id: options.deviceId,
    command: options.command,
    payload: options.payload,
    mqtt_response_status: options.mqttResponseStatus ?? null,
    error_details: options.errorDetails ?? null,
    simulated: options.simulated,
    created_at: new Date().toISOString(),
  });

  if (error) {
    throw new HttpError(500, "Failed to write MQTT audit log", {
      detail: error.message,
    });
  }
}

serve(async (request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) {
    return corsResponse;
  }

  if (request.method !== "POST") {
    return methodNotAllowed(request);
  }

  const supabase = createServiceRoleClient();

  try {
    const context = await requireAuthenticatedUser(request, supabase);
    requireRole(context, ["admin", "practitioner"]);

    const rawBody = await request.json().catch(() => {
      throw new HttpError(400, "Request body must be valid JSON");
    });
    const commandRequest = parseMqttCommandRequest(rawBody);
    const device = await fetchDevice(
      supabase,
      context.clinicId,
      commandRequest.deviceId,
    );

    const newStatus = getNextStatus(device.status, commandRequest.command);
    if (!newStatus) {
      return errorResponse(request, 409, "Invalid state transition", {
        command: commandRequest.command,
        currentStatus: device.status,
        detail: describeInvalidTransition(device.status, commandRequest.command),
      });
    }

    if (commandRequest.command === "start" && commandRequest.sessionConfig) {
      const validation = validateSafeEnvelope(
        commandRequest.sessionConfig,
        commandRequest.bodyRegion,
      );

      if (!validation.valid) {
        return errorResponse(request, 400, "SessionConfig outside safe envelope", {
          violations: validation.violations,
        });
      }
    }

    const payload = buildMqttPayload(
      commandRequest.command,
      device.device_mac,
      commandRequest.sessionConfig,
    ) as Record<string, unknown>;

    if (isSimulationMode()) {
      await updateDeviceStatus(
        supabase,
        device.id,
        context.clinicId,
        newStatus,
      );
      await insertAuditLog(supabase, {
        clinicId: context.clinicId,
        deviceId: device.id,
        command: commandRequest.command,
        payload,
        mqttResponseStatus: 200,
        simulated: true,
      });

      return jsonResponse(request, {
        success: true,
        simulated: true,
        command: commandRequest.command,
        deviceMac: device.device_mac,
        newStatus,
      }, { status: 200 });
    }

    const clinicToken = await fetchClinicToken(supabase, context.clinicId);

    let mqttResponse: Response;
    try {
      mqttResponse = await fetch(
        `${getHydrawavApiBaseUrl()}/api/v1/mqtt/publish`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": toAuthorizationHeader(clinicToken.access_token ?? ""),
          },
          body: JSON.stringify({
            topic: HYDRAWAV_TOPIC,
            payload: JSON.stringify(payload),
          }),
        },
      );
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);

      await insertAuditLog(supabase, {
        clinicId: context.clinicId,
        deviceId: device.id,
        command: commandRequest.command,
        payload,
        mqttResponseStatus: null,
        simulated: false,
        errorDetails: detail,
      });

      throw new HttpError(502, "MQTT publish request could not be completed", {
        detail,
      });
    }

    const mqttResponseText = await mqttResponse.text();

    if (!mqttResponse.ok) {
      await insertAuditLog(supabase, {
        clinicId: context.clinicId,
        deviceId: device.id,
        command: commandRequest.command,
        payload,
        mqttResponseStatus: mqttResponse.status,
        simulated: false,
        errorDetails: mqttResponseText || `Hydrawav returned ${mqttResponse.status}`,
      });

      return errorResponse(request, 502, "MQTT publish failed", {
        status: mqttResponse.status,
        detail: mqttResponseText,
      });
    }

    await updateDeviceStatus(
      supabase,
      device.id,
      context.clinicId,
      newStatus,
    );
    await insertAuditLog(supabase, {
      clinicId: context.clinicId,
      deviceId: device.id,
      command: commandRequest.command,
      payload,
      mqttResponseStatus: mqttResponse.status,
      simulated: false,
    });

    return jsonResponse(request, {
      success: true,
      simulated: false,
      command: commandRequest.command,
      deviceMac: device.device_mac,
      newStatus,
    }, { status: 200 });
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(request, error.status, error.message, error.details);
    }

    console.error("hydrawav-mqtt unexpected error", error);
    return errorResponse(request, 500, "Unexpected server error");
  }
});
