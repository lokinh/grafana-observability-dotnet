#!/bin/bash

echo "=== Testing OpenTelemetry Collector Integration ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test 1: Check if services are running
echo "1. Checking if services are running..."
docker compose ps | grep -E "(loki|tempo|otelcollector)" | grep "Up"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Services are running${NC}"
else
    echo -e "${RED}✗ Some services are not running${NC}"
    exit 1
fi
echo ""

# Test 2: Check Tempo health (from inside Docker network)
echo "2. Checking Tempo health..."
TEMPO_HEALTH=$(docker exec otelcollector sh -c "wget -qO- -T 2 http://tempo:3200/ready 2>/dev/null | head -c 10" 2>/dev/null || echo "")
if [ -n "$TEMPO_HEALTH" ]; then
    echo -e "${GREEN}✓ Tempo is ready (checked via Docker network)${NC}"
    TEMPO_READY=true
else
    echo -e "${YELLOW}⚠ Tempo health check via network failed, checking logs...${NC}"
    docker logs tempo --tail 20 | grep -i "ready\|error" | tail -5
    TEMPO_READY=false
fi
echo ""

# Test 3: Check Loki health
echo "3. Checking Loki health..."
LOKI_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready 2>/dev/null)
if [ "$LOKI_HEALTH" = "200" ]; then
    echo -e "${GREEN}✓ Loki is ready${NC}"
else
    echo -e "${YELLOW}⚠ Loki health check failed, checking logs...${NC}"
    docker logs loki --tail 20 | grep -i "ready\|error" | tail -5
fi
echo ""

# Test 4: Check OTel Collector logs for errors
echo "4. Checking OpenTelemetry Collector logs for errors..."
OTEL_ERRORS=$(docker logs otelcollector --tail 50 2>&1 | grep -i "error\|failed" | wc -l)
if [ "$OTEL_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✓ No errors in OTel Collector logs${NC}"
else
    echo -e "${YELLOW}⚠ Found $OTEL_ERRORS potential errors in logs:${NC}"
    docker logs otelcollector --tail 50 2>&1 | grep -i "error\|failed" | tail -5
fi
echo ""

# Test 5: Send test log via OTLP HTTP
echo "5. Sending test log to OTel Collector via OTLP HTTP..."
TEST_LOG_JSON='{
  "resourceLogs": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": { "stringValue": "test-service" }
      }]
    },
    "scopeLogs": [{
      "scope": {},
      "logRecords": [{
        "timeUnixNano": "'$(date +%s)000000000'",
        "severityNumber": 9,
        "severityText": "INFO",
        "body": {
          "stringValue": "Test log message from script - $(date)"
        },
        "attributes": [{
          "key": "test",
          "value": { "stringValue": "true" }
        }]
      }]
    }]
  }]
}'

LOG_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d "$TEST_LOG_JSON")

HTTP_CODE=$(echo "$LOG_RESPONSE" | tail -1)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
    echo -e "${GREEN}✓ Test log sent successfully (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}✗ Failed to send test log (HTTP $HTTP_CODE)${NC}"
    echo "Response: $(echo "$LOG_RESPONSE" | head -1)"
fi
echo ""

# Test 6: Send test trace via OTLP HTTP
echo "6. Sending test trace to OTel Collector via OTLP HTTP..."
TRACE_ID=$(openssl rand -hex 16)
SPAN_ID=$(openssl rand -hex 8)
TEST_TRACE_JSON='{
  "resourceSpans": [{
    "resource": {
      "attributes": [{
        "key": "service.name",
        "value": { "stringValue": "test-service" }
      }]
    },
    "scopeSpans": [{
      "scope": {},
      "spans": [{
        "traceId": "'$TRACE_ID'",
        "spanId": "'$SPAN_ID'",
        "name": "test-span",
        "kind": 1,
        "startTimeUnixNano": "'$(date +%s)000000000'",
        "endTimeUnixNano": "'$(($(date +%s) + 1))000000000'",
        "attributes": [{
          "key": "test",
          "value": { "stringValue": "true" }
        }]
      }]
    }]
  }]
}'

TRACE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d "$TEST_TRACE_JSON")

HTTP_CODE=$(echo "$TRACE_RESPONSE" | tail -1)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "202" ]; then
    echo -e "${GREEN}✓ Test trace sent successfully (HTTP $HTTP_CODE)${NC}"
    echo "  Trace ID: $TRACE_ID"
else
    echo -e "${RED}✗ Failed to send test trace (HTTP $HTTP_CODE)${NC}"
    echo "Response: $(echo "$TRACE_RESPONSE" | head -1)"
fi
echo ""

# Test 7: Wait and check if data reached Loki
echo "7. Waiting 3 seconds and checking if log reached Loki..."
sleep 3
# Try from localhost first, then from Docker network
LOKI_QUERY=$(curl -s -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={service_name=\"test-service\"}" \
  --data-urlencode "start=$(($(date +%s) - 60))000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode "limit=10" 2>/dev/null)

if [ -z "$LOKI_QUERY" ] || echo "$LOKI_QUERY" | grep -q "null\|error"; then
    # Try from inside Docker network using a simpler query
    echo "  Trying to query Loki from Docker network..."
    START_TIME=$(($(date +%s) - 60))000000000
    END_TIME=$(date +%s)000000000
    LOKI_QUERY=$(docker exec otelcollector sh -c "wget -qO- -T 5 'http://loki:3100/loki/api/v1/query_range?query={service_name=\"test-service\"}&start=${START_TIME}&end=${END_TIME}&limit=10' 2>/dev/null" 2>/dev/null)
fi

if echo "$LOKI_QUERY" | grep -q "test-service\|Test log message"; then
    echo -e "${GREEN}✓ Log found in Loki!${NC}"
    echo "$LOKI_QUERY" | jq '.data.result[] | .stream' 2>/dev/null || echo "$LOKI_QUERY" | head -c 300
else
    echo -e "${YELLOW}⚠ Log not found in Loki yet (may take a few more seconds)${NC}"
    echo "  Query result: $(echo "$LOKI_QUERY" | head -c 200)..."
    echo "  Try querying manually: curl -G 'http://localhost:3100/loki/api/v1/query_range?query={service_name=\"test-service\"}'"
fi
echo ""

# Test 8: Check if trace reached Tempo (via Docker network)
echo "8. Checking if trace reached Tempo (via Docker network)..."
if [ "$TEMPO_READY" = "true" ]; then
    # Try to query Tempo from inside the network
    TEMPO_QUERY=$(docker exec otelcollector sh -c "wget -qO- -T 5 'http://tempo:3200/api/search?tags=service.name%3Dtest-service&limit=1' 2>/dev/null" 2>/dev/null)
    if [ -n "$TEMPO_QUERY" ] && (echo "$TEMPO_QUERY" | grep -q "$TRACE_ID\|test-service" 2>/dev/null); then
        echo -e "${GREEN}✓ Trace found in Tempo!${NC}"
        echo "  Trace ID: $TRACE_ID"
    else
        echo -e "${YELLOW}⚠ Trace not found in Tempo yet (may take a few more seconds)${NC}"
        echo "  You can check in Grafana UI at http://localhost:3000"
        echo "  Or query Tempo directly: docker exec otelcollector wget -qO- 'http://tempo:3200/api/search?tags=service.name%3Dtest-service'"
    fi
else
    echo -e "${YELLOW}⚠ Tempo not ready, check Grafana UI at http://localhost:3000${NC}"
fi
echo ""

# Test 9: Check OTel Collector metrics (via Docker network)
echo "9. Checking OTel Collector internal metrics (via Docker network)..."
# Try port 8888 (internal metrics) first
OTEL_METRICS=$(docker exec otelcollector sh -c "wget -qO- -T 2 http://localhost:8888/metrics 2>/dev/null | grep -i 'otelcol_exporter' | head -5" 2>/dev/null)
if [ -n "$OTEL_METRICS" ]; then
    echo -e "${GREEN}✓ OTel Collector internal metrics available (port 8888)${NC}"
    echo "$OTEL_METRICS"
    # Check for exporter success/failure counts
    EXPORTER_STATS=$(docker exec otelcollector sh -c "wget -qO- -T 2 http://localhost:8888/metrics 2>/dev/null | grep -E 'otelcol_exporter_(sent|send_failed|logs|traces)' | head -15" 2>/dev/null)
    if [ -n "$EXPORTER_STATS" ]; then
        echo ""
        echo "Exporter statistics:"
        echo "$EXPORTER_STATS"
    fi
else
    # Try port 8889 (prometheus exporter)
    echo "  Trying port 8889 (prometheus exporter)..."
    OTEL_METRICS=$(docker exec otelcollector sh -c "wget -qO- -T 2 http://localhost:8889/metrics 2>/dev/null | head -20" 2>/dev/null)
    if [ -n "$OTEL_METRICS" ]; then
        echo -e "${GREEN}✓ OTel Collector prometheus exporter metrics available (port 8889)${NC}"
        echo "$OTEL_METRICS" | head -10
    else
        echo -e "${YELLOW}⚠ OTel Collector metrics endpoints not accessible${NC}"
        echo "  Checking if metrics extension is enabled in config..."
        docker exec otelcollector cat /etc/otel-collector-config.yml 2>/dev/null | grep -i "extensions\|8888\|8889" | head -5 || echo "  No metrics config found"
    fi
fi
echo ""

echo "=== Test Summary ==="
echo "To view data in Grafana:"
echo "  - Open http://localhost:3000"
echo "  - Go to Explore and select Loki datasource to see logs"
echo "  - Go to Explore and select Tempo datasource to see traces"
echo ""
echo "To check logs manually:"
echo "  - Loki logs: docker logs loki --tail 50"
echo "  - Tempo logs: docker logs tempo --tail 50"
echo "  - OTel Collector logs: docker logs otelcollector --tail 50"

