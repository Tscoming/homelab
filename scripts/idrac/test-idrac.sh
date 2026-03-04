#!/bin/bash
# iDRAC API Test Script
# Usage: ./test-idrac.sh <idrac_host> <username> <password>

IDRAC_HOST="${1:-192.168.1.100}"
IDRAC_USER="${2:-admin}"
IDRAC_PASS="${3:-password}"
BASE_URL="https://${IDRAC_HOST}/redfish/v1"

# Get session token
echo "=== Getting session token ==="
SESSION_RESPONSE=$(curl -k -s -X POST "${BASE_URL}/Sessions" \
  -H "Content-Type: application/json" \
  -d "{\"UserName\":\"${IDRAC_USER}\",\"Password\":\"${IDRAC_PASS}\"}")

TOKEN=$(echo "$SESSION_RESPONSE" | grep -o '"Token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Failed to get session token"
  echo "Response: $SESSION_RESPONSE"
  exit 1
fi

echo "Session token obtained"

# Test API endpoints
echo ""
echo "=== Testing iDRAC API Endpoints ==="

# Get Systems info
echo -e "\n--- GET /Systems ---"
curl -k -s -X GET "${BASE_URL}/Systems" \
  -H "Authorization: Bearer ${TOKEN}" | head -c 500

# Get Managers info
echo -e "\n--- GET /Managers ---"
curl -k -s -X GET "${BASE_URL}/Managers" \
  -H "Authorization: Bearer ${TOKEN}" | head -c 500

# Get Chassis info
echo -e "\n--- GET /Chassis ---"
curl -k -s -X GET "${BASE_URL}/Chassis" \
  -H "Authorization: Bearer ${TOKEN}" | head -c 500

# Delete session
echo -e "\n\n--- Deleting session ---"
curl -k -s -X DELETE "${BASE_URL}/Sessions" \
  -H "Authorization: Bearer ${TOKEN}"

echo -e "\n\nTest completed!"
