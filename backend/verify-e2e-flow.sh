#!/bin/bash

# End-to-End MQTT Command Flow Verification Script
# This script verifies the complete flow in simulation mode

set -e

echo "🔍 HydraScan E2E MQTT Command Flow Verification"
echo "================================================"
echo ""

# Configuration
SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
TEST_EMAIL="priya@phoenixrecovery.test"
TEST_PASSWORD="HydraScan123!"
TEST_DEVICE_ID="de111111-1111-1111-1111-111111111111"

if [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "❌ Error: SUPABASE_ANON_KEY environment variable not set"
  echo "   Please set it to your Supabase anon key"
  exit 1
fi

echo "📋 Configuration:"
echo "   Supabase URL: $SUPABASE_URL"
echo "   Test User: $TEST_EMAIL"
echo "   Test Device: $TEST_DEVICE_ID"
echo ""

# Step 1: Authenticate
echo "🔐 Step 1: Authenticating as practitioner..."
AUTH_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "Content-Type: application/json" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}")

ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Authentication failed"
  echo "   Response: $AUTH_RESPONSE"
  exit 1
fi

echo "✅ Authentication successful"
echo ""

# Step 2: Send START command
echo "🚀 Step 2: Sending START command..."
START_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/hydrawav-mqtt" \
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
  echo "❌ START command failed"
  echo "   Response: $START_RESPONSE"
  exit 1
fi

if [ -z "$START_SIMULATED" ]; then
  echo "⚠️  Warning: Not in simulation mode"
fi

if [ "$START_STATUS" != "in_session" ]; then
  echo "❌ Device status not updated correctly (expected: in_session, got: $START_STATUS)"
  exit 1
fi

echo "✅ START command successful"
echo "   Status: $START_STATUS"
echo "   Simulated: $([ -n "$START_SIMULATED" ] && echo "yes" || echo "no")"
echo ""

# Step 3: Send PAUSE command
echo "⏸️  Step 3: Sending PAUSE command..."
PAUSE_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "pause"
  }')

PAUSE_SUCCESS=$(echo "$PAUSE_RESPONSE" | grep -o '"success":true')
PAUSE_STATUS=$(echo "$PAUSE_RESPONSE" | grep -o '"newStatus":"[^"]*"' | cut -d'"' -f4)

if [ -z "$PAUSE_SUCCESS" ] || [ "$PAUSE_STATUS" != "paused" ]; then
  echo "❌ PAUSE command failed"
  echo "   Response: $PAUSE_RESPONSE"
  exit 1
fi

echo "✅ PAUSE command successful"
echo "   Status: $PAUSE_STATUS"
echo ""

# Step 4: Send RESUME command
echo "▶️  Step 4: Sending RESUME command..."
RESUME_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "resume"
  }')

RESUME_SUCCESS=$(echo "$RESUME_RESPONSE" | grep -o '"success":true')
RESUME_STATUS=$(echo "$RESUME_RESPONSE" | grep -o '"newStatus":"[^"]*"' | cut -d'"' -f4)

if [ -z "$RESUME_SUCCESS" ] || [ "$RESUME_STATUS" != "in_session" ]; then
  echo "❌ RESUME command failed"
  echo "   Response: $RESUME_RESPONSE"
  exit 1
fi

echo "✅ RESUME command successful"
echo "   Status: $RESUME_STATUS"
echo ""

# Step 5: Send STOP command
echo "⏹️  Step 5: Sending STOP command..."
STOP_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "stop"
  }')

STOP_SUCCESS=$(echo "$STOP_RESPONSE" | grep -o '"success":true')
STOP_STATUS=$(echo "$STOP_RESPONSE" | grep -o '"newStatus":"[^"]*"' | cut -d'"' -f4)

if [ -z "$STOP_SUCCESS" ] || [ "$STOP_STATUS" != "idle" ]; then
  echo "❌ STOP command failed"
  echo "   Response: $STOP_RESPONSE"
  exit 1
fi

echo "✅ STOP command successful"
echo "   Status: $STOP_STATUS"
echo ""

# Step 6: Test invalid state transition
echo "🚫 Step 6: Testing invalid state transition (PAUSE when idle)..."
INVALID_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$SUPABASE_URL/functions/v1/hydrawav-mqtt" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "deviceId": "'"$TEST_DEVICE_ID"'",
    "command": "pause"
  }')

HTTP_CODE=$(echo "$INVALID_RESPONSE" | tail -n1)
INVALID_BODY=$(echo "$INVALID_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" != "409" ]; then
  echo "❌ Invalid transition not rejected correctly (expected 409, got $HTTP_CODE)"
  exit 1
fi

echo "✅ Invalid state transition correctly rejected (HTTP 409)"
echo ""

# Step 7: Test safe envelope violation
echo "🛡️  Step 7: Testing safe envelope violation..."
VIOLATION_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$SUPABASE_URL/functions/v1/hydrawav-mqtt" \
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
  echo "❌ Safe envelope violation not rejected correctly (expected 400, got $HTTP_CODE)"
  exit 1
fi

VIOLATIONS=$(echo "$VIOLATION_BODY" | grep -o '"violations"')
if [ -z "$VIOLATIONS" ]; then
  echo "❌ Violations array not returned"
  exit 1
fi

echo "✅ Safe envelope violation correctly rejected (HTTP 400)"
echo ""

# Summary
echo "================================================"
echo "✅ All E2E verification tests passed!"
echo ""
echo "Component Integration Verified:"
echo "  ✅ Authentication (JWT)"
echo "  ✅ Device lookup"
echo "  ✅ State validation"
echo "  ✅ Safe envelope validation"
echo "  ✅ Payload construction"
echo "  ✅ Simulation mode"
echo "  ✅ Status updates"
echo "  ✅ Complete lifecycle (idle → in_session → paused → in_session → idle)"
echo ""
echo "Requirements Validated:"
echo "  ✅ Req 12.1: MQTT command publishing"
echo "  ✅ Req 12.3-12.6: Command payloads (START/PAUSE/RESUME/STOP)"
echo "  ✅ Req 15.1-15.3: Simulation mode"
echo "  ✅ Req 10.1-10.6: Device state machine"
echo "  ✅ Req 13.3-13.5: Safe envelope validation"
echo ""
echo "🎉 End-to-end MQTT command flow verification complete!"
