/**
 * End-to-End Integration Test for MQTT Command Flow
 * 
 * This test verifies the complete request flow from authenticated user
 * to simulated command response, covering:
 * - Auth → device lookup → state validation → safe envelope → 
 *   payload build → simulation → status update → audit log
 * 
 * Requirements: 12.1, 15.1, 15.2, 15.3
 */

import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createClient } from "npm:@insforge/sdk@1.2.5";

const INSFORGE_URL = Deno.env.get("INSFORGE_URL") || "http://127.0.0.1:7130";
const INSFORGE_ANON_KEY = Deno.env.get("INSFORGE_ANON_KEY") || "";
const FUNCTION_URL = `${INSFORGE_URL}/functions/hydrawav-mqtt`;

// Test user credentials from seed data
const TEST_PRACTITIONER_EMAIL = "priya@phoenixrecovery.test";
const TEST_PRACTITIONER_PASSWORD = "HydraScan123!";
const TEST_DEVICE_ID = "de111111-1111-1111-1111-111111111111"; // Hydra Bay 1, status: idle

interface MqttCommandRequest {
  deviceId: string;
  command: "start" | "pause" | "resume" | "stop";
  sessionConfig?: {
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
    leftFuncs: string[];
    rightFuncs: string[];
    pwmValues: {
      hot: [number, number, number];
      cold: [number, number, number];
    };
    led: 0 | 1;
    hotDrop: number;
    coldDrop: number;
    vibMin: number;
    vibMax: number;
    totalDuration: number;
  };
  bodyRegion?: string;
}

interface MqttCommandResponse {
  success: boolean;
  simulated: boolean;
  command: string;
  deviceMac: string;
  newStatus: string;
  error?: string;
  violations?: Array<{
    parameter: string;
    actual: number;
    min: number;
    max: number;
  }>;
}

async function authenticateUser(email: string, password: string): Promise<string> {
  const insforge = createClient({
    baseUrl: INSFORGE_URL,
    anonKey: INSFORGE_ANON_KEY,
    isServerMode: true,
    autoRefreshToken: false,
  });
  
  const { data, error } = await insforge.auth.signInWithPassword({
    email,
    password,
  });

  if (error || !data?.accessToken) {
    throw new Error(`Authentication failed: ${error?.message}`);
  }

  return data.accessToken;
}

async function sendMqttCommand(
  token: string,
  request: MqttCommandRequest,
): Promise<MqttCommandResponse> {
  const response = await fetch(FUNCTION_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
    },
    body: JSON.stringify(request),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`MQTT command failed: ${response.status} ${errorText}`);
  }

  return await response.json();
}

async function getDeviceStatus(token: string, deviceId: string): Promise<string> {
  const insforge = createClient({
    baseUrl: INSFORGE_URL,
    anonKey: INSFORGE_ANON_KEY,
    edgeFunctionToken: token,
    isServerMode: true,
    autoRefreshToken: false,
  });

  const { data, error } = await insforge.database
    .from("devices")
    .select("status")
    .eq("id", deviceId)
    .single();

  if (error) {
    throw new Error(`Failed to fetch device status: ${error.message}`);
  }

  return data.status;
}

async function getLatestAuditLog(token: string, deviceId: string) {
  const insforge = createClient({
    baseUrl: INSFORGE_URL,
    anonKey: INSFORGE_ANON_KEY,
    edgeFunctionToken: token,
    isServerMode: true,
    autoRefreshToken: false,
  });

  const { data, error } = await insforge.database
    .from("mqtt_command_log")
    .select("*")
    .eq("device_id", deviceId)
    .order("created_at", { ascending: false })
    .limit(1)
    .single();

  if (error) {
    throw new Error(`Failed to fetch audit log: ${error.message}`);
  }

  return data;
}

Deno.test("End-to-end MQTT command flow in simulation mode", async (t) => {
  // Step 1: Authenticate as practitioner
  await t.step("Authenticate practitioner user", async () => {
    const token = await authenticateUser(
      TEST_PRACTITIONER_EMAIL,
      TEST_PRACTITIONER_PASSWORD,
    );
    assertExists(token, "Authentication token should be returned");
  });

  const token = await authenticateUser(
    TEST_PRACTITIONER_EMAIL,
    TEST_PRACTITIONER_PASSWORD,
  );

  // Step 2: Verify initial device status is idle
  await t.step("Verify device initial status is idle", async () => {
    const status = await getDeviceStatus(token, TEST_DEVICE_ID);
    assertEquals(status, "idle", "Device should start in idle state");
  });

  // Step 3: Send START command with valid SessionConfig
  await t.step("Send START command with valid SessionConfig", async () => {
    const startRequest: MqttCommandRequest = {
      deviceId: TEST_DEVICE_ID,
      command: "start",
      sessionConfig: {
        sessionCount: 1,
        sessionPause: 0,
        sDelay: 0,
        cycle1: 1,
        cycle5: 5,
        edgeCycleDuration: 8,
        cycleRepetitions: [3],
        cycleDurations: [60],
        cyclePauses: [10],
        pauseIntervals: [0],
        leftFuncs: ["leftHotRed"],
        rightFuncs: ["rightColdBlue"],
        pwmValues: {
          hot: [90, 90, 90],
          cold: [180, 180, 180],
        },
        led: 1,
        hotDrop: 3,
        coldDrop: 2,
        vibMin: 15,
        vibMax: 120,
        totalDuration: 1200,
      },
      bodyRegion: "lower_back",
    };

    const response = await sendMqttCommand(token, startRequest);

    assertEquals(response.success, true, "Command should succeed");
    assertEquals(response.simulated, true, "Should be in simulation mode");
    assertEquals(response.command, "start", "Command type should be start");
    assertEquals(response.newStatus, "in_session", "Device should transition to in_session");
    assertExists(response.deviceMac, "Device MAC should be returned");
  });

  // Step 4: Verify device status updated to in_session
  await t.step("Verify device status updated to in_session", async () => {
    const status = await getDeviceStatus(token, TEST_DEVICE_ID);
    assertEquals(status, "in_session", "Device should be in_session after start");
  });

  // Step 5: Verify audit log entry was created
  await t.step("Verify audit log entry created for START command", async () => {
    const auditLog = await getLatestAuditLog(token, TEST_DEVICE_ID);

    assertEquals(auditLog.command, "start", "Audit log should record start command");
    assertEquals(auditLog.simulated, true, "Audit log should mark as simulated");
    assertEquals(auditLog.mqtt_response_status, 200, "Should log success status");
    assertExists(auditLog.payload, "Audit log should contain payload");
    assertExists(auditLog.payload.mac, "Payload should contain device MAC");
    assertEquals(auditLog.payload.playCmd, 1, "Payload should have playCmd=1 for start");
  });

  // Step 6: Send PAUSE command
  await t.step("Send PAUSE command", async () => {
    const pauseRequest: MqttCommandRequest = {
      deviceId: TEST_DEVICE_ID,
      command: "pause",
    };

    const response = await sendMqttCommand(token, pauseRequest);

    assertEquals(response.success, true, "Pause command should succeed");
    assertEquals(response.simulated, true, "Should be in simulation mode");
    assertEquals(response.command, "pause", "Command type should be pause");
    assertEquals(response.newStatus, "paused", "Device should transition to paused");
  });

  // Step 7: Verify device status updated to paused
  await t.step("Verify device status updated to paused", async () => {
    const status = await getDeviceStatus(token, TEST_DEVICE_ID);
    assertEquals(status, "paused", "Device should be paused");
  });

  // Step 8: Send RESUME command
  await t.step("Send RESUME command", async () => {
    const resumeRequest: MqttCommandRequest = {
      deviceId: TEST_DEVICE_ID,
      command: "resume",
    };

    const response = await sendMqttCommand(token, resumeRequest);

    assertEquals(response.success, true, "Resume command should succeed");
    assertEquals(response.simulated, true, "Should be in simulation mode");
    assertEquals(response.command, "resume", "Command type should be resume");
    assertEquals(response.newStatus, "in_session", "Device should transition back to in_session");
  });

  // Step 9: Verify device status back to in_session
  await t.step("Verify device status back to in_session", async () => {
    const status = await getDeviceStatus(token, TEST_DEVICE_ID);
    assertEquals(status, "in_session", "Device should be in_session after resume");
  });

  // Step 10: Send STOP command
  await t.step("Send STOP command", async () => {
    const stopRequest: MqttCommandRequest = {
      deviceId: TEST_DEVICE_ID,
      command: "stop",
    };

    const response = await sendMqttCommand(token, stopRequest);

    assertEquals(response.success, true, "Stop command should succeed");
    assertEquals(response.simulated, true, "Should be in simulation mode");
    assertEquals(response.command, "stop", "Command type should be stop");
    assertEquals(response.newStatus, "idle", "Device should transition back to idle");
  });

  // Step 11: Verify device status back to idle
  await t.step("Verify device status back to idle", async () => {
    const status = await getDeviceStatus(token, TEST_DEVICE_ID);
    assertEquals(status, "idle", "Device should be idle after stop");
  });

  // Step 12: Verify complete lifecycle in audit log
  await t.step("Verify complete lifecycle recorded in audit log", async () => {
    const insforge = createClient({
      baseUrl: INSFORGE_URL,
      anonKey: INSFORGE_ANON_KEY,
      edgeFunctionToken: token,
      isServerMode: true,
      autoRefreshToken: false,
    });

    const { data: logs, error } = await insforge.database
      .from("mqtt_command_log")
      .select("command, simulated, mqtt_response_status")
      .eq("device_id", TEST_DEVICE_ID)
      .order("created_at", { ascending: true })
      .limit(4);

    if (error) {
      throw new Error(`Failed to fetch audit logs: ${error.message}`);
    }

    // Should have at least 4 commands: start, pause, resume, stop
    assertEquals(logs.length >= 4, true, "Should have at least 4 audit log entries");
    
    const recentCommands = logs.slice(-4).map(log => log.command);
    assertEquals(recentCommands, ["start", "pause", "resume", "stop"], 
      "Audit log should show complete lifecycle");
    
    logs.forEach(log => {
      assertEquals(log.simulated, true, "All commands should be simulated");
      assertEquals(log.mqtt_response_status, 200, "All commands should succeed");
    });
  });
});

Deno.test("Safe envelope validation rejects out-of-range values", async (t) => {
  const token = await authenticateUser(
    TEST_PRACTITIONER_EMAIL,
    TEST_PRACTITIONER_PASSWORD,
  );

  // Reset device to idle if needed
  const currentStatus = await getDeviceStatus(token, TEST_DEVICE_ID);
  if (currentStatus !== "idle") {
    await sendMqttCommand(token, {
      deviceId: TEST_DEVICE_ID,
      command: "stop",
    });
  }

  await t.step("Reject SessionConfig with pwmHot value too high", async () => {
    const invalidRequest: MqttCommandRequest = {
      deviceId: TEST_DEVICE_ID,
      command: "start",
      sessionConfig: {
        sessionCount: 1,
        sessionPause: 0,
        sDelay: 0,
        cycle1: 1,
        cycle5: 5,
        edgeCycleDuration: 8,
        cycleRepetitions: [3],
        cycleDurations: [60],
        cyclePauses: [10],
        pauseIntervals: [0],
        leftFuncs: ["leftHotRed"],
        rightFuncs: ["rightColdBlue"],
        pwmValues: {
          hot: [200, 200, 200], // Too high! Max is 150
          cold: [180, 180, 180],
        },
        led: 1,
        hotDrop: 3,
        coldDrop: 2,
        vibMin: 15,
        vibMax: 120,
        totalDuration: 1200,
      },
    };

    try {
      const response = await fetch(FUNCTION_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify(invalidRequest),
      });

      assertEquals(response.status, 400, "Should return 400 for safe envelope violation");

      const errorData = await response.json();
      assertExists(errorData.violations, "Should return violations array");
      assertEquals(errorData.violations.length > 0, true, "Should have at least one violation");
      
      const hotViolation = errorData.violations.find((v: any) => 
        v.parameter.includes("pwmValues.hot")
      );
      assertExists(hotViolation, "Should report pwmValues.hot violation");
      assertEquals(hotViolation.actual, 200, "Should report actual value");
      assertEquals(hotViolation.max, 150, "Should report max allowed value");
    } catch (error) {
      throw new Error(`Test failed: ${error}`);
    }
  });
});

Deno.test("Invalid state transitions are rejected", async (t) => {
  const token = await authenticateUser(
    TEST_PRACTITIONER_EMAIL,
    TEST_PRACTITIONER_PASSWORD,
  );

  // Ensure device is in idle state
  const currentStatus = await getDeviceStatus(token, TEST_DEVICE_ID);
  if (currentStatus !== "idle") {
    await sendMqttCommand(token, {
      deviceId: TEST_DEVICE_ID,
      command: "stop",
    });
  }

  await t.step("Reject PAUSE command when device is idle", async () => {
    try {
      const response = await fetch(FUNCTION_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({
          deviceId: TEST_DEVICE_ID,
          command: "pause",
        }),
      });

      assertEquals(response.status, 409, "Should return 409 for invalid state transition");

      const errorData = await response.json();
      assertExists(errorData.error, "Should return error message");
      assertExists(errorData.currentStatus, "Should report current status");
      assertEquals(errorData.currentStatus, "idle", "Should report device is idle");
    } catch (error) {
      throw new Error(`Test failed: ${error}`);
    }
  });

  await t.step("Reject RESUME command when device is idle", async () => {
    try {
      const response = await fetch(FUNCTION_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${token}`,
        },
        body: JSON.stringify({
          deviceId: TEST_DEVICE_ID,
          command: "resume",
        }),
      });

      assertEquals(response.status, 409, "Should return 409 for invalid state transition");
    } catch (error) {
      throw new Error(`Test failed: ${error}`);
    }
  });
});
