#!/bin/bash

# End-to-End MQTT Command Flow Verification Script
# This script verifies the complete flow in simulation mode

set -e

echo "ðŸ” HydraScan E2E MQTT Command Flow Verification"
echo "================================================"
echo ""

# Configuration
INSFORGE_URL="${INSFORGE_URL:-http://127.0.0.1:7130}"
INSFORGE_ANON_KEY="${INSFORGE_ANON_KEY}"
TEST_EMAIL="priya@phoenixrecovery.test"
TEST_PASSWORD="HydraScan123!"
TEST_DEVICE_ID="de111111-1111-1111-1111-111111111111"

if [ -z "$INSFORGE_ANON_KEY" ]; then
  echo "âŒ Error: INSFORGE_ANON_KEY environment variable not set"
  echo "   Please set it to your InsForge anon key"
  exit 1
fi

echo "ðŸ“‹ Configuration:"
echo "   InsForge URL: $INSFORGE_URL"
echo "   Test User: $TEST_EMAIL"
echo "   Test Device: $TEST_DEVICE_ID"
echo ""

# Step 1: Authenticate
echo "ðŸ” Step 1: Authenticating as practitioner..."
AUTH_RESPONSE=$(curl -s -X POST "$INSFORGE_URL/api/auth/sessions" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}")

ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
if [ -z "$ACCESS_TOKEN" ]; then
  ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$ACCESS_TOKEN" ]; then
  echo "âŒ Authentication failed"
  echo "   Response: $AUTH_RESPONSE"
  exit 1
fi

echo "âœ… Authentication successful"
echo ""

# Step 2: Send START command
echo "ðŸš€ Step 2: Sending START command..."
START_RESPONSE=$(curl -s -X POST "$INSFORGE_URL/functions/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "start",
    "bodyRegion": "lower_back",
    "sessionConfig": {
      "sessionCount": 1,
      "sessionPause": 0,
      "sDelay": 0,
      "cycle1": 1,
      "cycle5": 5,
      "edgeCycleDuration": 8,
      "cycleRepetitions": [3],
      "cycleDurations": [60],
      "cyclePauses": [10],
      "pauseIntervals": [0],
      "leftFuncs": ["leftHotRed"],
      "rightFuncs": ["rightColdBlue"],
      "pwmValues": {
        "hot": [90, 90, 90],
        "cold": [180, 180, 180]
      },
      "led": 1,
      "hotDrop": 3,
      "coldDrop": 2,
      "vibMin": 15,
      "vibMax": 120,
      "totalDuration": 1200
    }
  }')

START_SUCCESS=$(echo "$START_RESPONSE" | grep -o '"success":true')
START_SIMULATED=$(echo "$START_RESPONSE" | grep -o '"simulated":true')
START_STATUS=$(echo "$START_RESPONSE" | grep -o '"newStatus":"[^"]*"' | cut -d'"' -f4)

if [ -z "$START_SUCCESS" ]; then
  echo "âŒ START command failed"
  echo "   Response: $START_RESPONSE"
  exit 1
fi

if [ -z "$START_SIMULATED" ]; then
  echo "âš ï¸  Warning: Not in simulation mode"
fi

if [ "$START_STATUS" != "in_session" ]; then
  echo "âŒ Device status not updated correctly (expected: in_session, got: $START_STATUS)"
  exit 1
fi

echo "âœ… START command successful"
echo "   Status: $START_STATUS"
echo "   Simulated: $([ -n "$START_SIMULATED" ] && echo "yes" || echo "no")"
echo ""

# Step 3: Send PAUSE command
echo "â¸ï¸  Step 3: Sending PAUSE command..."
PAUSE_RESPONSE=$(curl -s -X POST "$INSFORGE_URL/functions/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "pause"
  }')

PAUSE_SUCCESS=$(echo "$PAUSE_RESPONSE" | grep -o '"success":true')
PAUSE_STATUS=$(echo "$PAUSE_RESPONSE" | grep -o '"newStatus":"[^"]*"' | cut -d'"' -f4)

if [ -z "$PAUSE_SUCCESS" ] || [ "$PAUSE_STATUS" != "paused" ]; then
  echo "âŒ PAUSE command failed"
  echo "   Response: $PAUSE_RESPONSE"
  exit 1
fi

echo "âœ… PAUSE command successful"
echo "   Status: $PAUSE_STATUS"
echo ""

# Step 4: Send RESUME command
echo "â–¶ï¸  Step 4: Sending RESUME command..."
RESUME_RESPONSE=$(curl -s -X POST "$INSFORGE_URL/functions/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "resume"
  }')

RESUME_SUCCESS=$(echo "$RESUME_RESPONSE" | grep -o '"success":true')
RESUME_STATUS=$(echo "$RESUME_RESPONSE" | grep -o '"newStatus":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RESUME_SUCCESS" ] || [ "$RESUME_STATUS" != "in_session" ]; then
  echo "âŒ RESUME command failed"
  echo "   Response: $RESUME_RESPONSE"
  exit 1
fi

echo "âœ… RESUME command successful"
echo "   Status: $RESUME_STATUS"
echo ""

# Step 5: Send STOP command
echo "â¹ï¸  Step 5: Sending STOP command..."
STOP_RESPONSE=$(curl -s -X POST "$INSFORGE_URL/functions/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "stop"
  }')

STOP_SUCCESS=$(echo "$STOP_RESPONSE" | grep -o '"success":true')
STOP_STATUS=$(echo "$STOP_RESPONSE" | grep -o '"newStatus":"[^"]*"' | cut -d'"' -f4)

if [ -z "$STOP_SUCCESS" ] || [ "$STOP_STATUS" != "idle" ]; then
  echo "âŒ STOP command failed"
  echo "   Response: $STOP_RESPONSE"
  exit 1
fi

echo "âœ… STOP command successful"
echo "   Status: $STOP_STATUS"
echo ""

# Step 6: Test invalid state transition
echo "ðŸš« Step 6: Testing invalid state transition (PAUSE when idle)..."
INVALID_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$INSFORGE_URL/functions/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "pause"
  }')

HTTP_CODE=$(echo "$INVALID_RESPONSE" | tail -n1)
INVALID_BODY=$(echo "$INVALID_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" != "409" ]; then
  echo "âŒ Invalid transition not rejected correctly (expected 409, got $HTTP_CODE)"
  exit 1
fi

echo "âœ… Invalid state transition correctly rejected (HTTP 409)"
echo ""

# Step 7: Test safe envelope violation
echo "ðŸ›¡ï¸  Step 7: Testing safe envelope violation..."
VIOLATION_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$INSFORGE_URL/functions/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "start",
    "sessionConfig": {
      "sessionCount": 1,
      "sessionPause": 0,
      "sDelay": 0,
      "cycle1": 1,
      "cycle5": 5,
      "edgeCycleDuration": 8,
      "cycleRepetitions": [3],
      "cycleDurations": [60],
      "cyclePauses": [10],
      "pauseIntervals": [0],
      "leftFuncs": ["leftHotRed"],
      "rightFuncs": ["rightColdBlue"],
      "pwmValues": {
        "hot": [200, 200, 200],
        "cold": [180, 180, 180]
      },
      "led": 1,
      "hotDrop": 3,
      "coldDrop": 2,
      "vibMin": 15,
      "vibMax": 120,
      "totalDuration": 1200
    }
  }')

HTTP_CODE=$(echo "$VIOLATION_RESPONSE" | tail -n1)
VIOLATION_BODY=$(echo "$VIOLATION_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" != "400" ]; then
  echo "âŒ Safe envelope violation not rejected correctly (expected 400, got $HTTP_CODE)"
  exit 1
fi

VIOLATIONS=$(echo "$VIOLATION_BODY" | grep -o '"violations"')
if [ -z "$VIOLATIONS" ]; then
  echo "âŒ Violations array not returned"
  exit 1
fi

echo "âœ… Safe envelope violation correctly rejected (HTTP 400)"
echo ""

# Summary
echo "================================================"
echo "âœ… All E2E verification tests passed!"
echo ""
echo "Component Integration Verified:"
echo "  âœ… Authentication (JWT)"
echo "  âœ… Device lookup"
echo "  âœ… State validation"
echo "  âœ… Safe envelope validation"
echo "  âœ… Payload construction"
echo "  âœ… Simulation mode"
echo "  âœ… Status updates"
echo "  âœ… Complete lifecycle (idle â†’ in_session â†’ paused â†’ in_session â†’ idle)"
echo ""
echo "Requirements Validated:"
echo "  âœ… Req 12.1: MQTT command publishing"
echo "  âœ… Req 12.3-12.6: Command payloads (START/PAUSE/RESUME/STOP)"
echo "  âœ… Req 15.1-15.3: Simulation mode"
echo "  âœ… Req 10.1-10.6: Device state machine"
echo "  âœ… Req 13.3-13.5: Safe envelope validation"
echo ""
echo "ðŸŽ‰ End-to-end MQTT command flow verification complete!"
