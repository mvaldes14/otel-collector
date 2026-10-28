#!/usr/bin/env bash
# Push one hand-built trace + one log straight at the collector's OTLP/HTTP port.
# No SDK, no dependencies — the payloads are the wire format itself, which is the
# fastest way to see that OTLP is just JSON (HTTP) or protobuf (gRPC).
#
# Usage: ./generate-telemetry.sh [host] [port]
set -euo pipefail
HOST="${1:-localhost}"
PORT="${2:-4318}"

# OTLP/JSON trace: one resource, one scope, one span with an ERROR status so
# tail_sampling's keep-all-errors policy (04) would retain it.
TRACE='{
  "resourceSpans": [{
    "resource": {"attributes": [
      {"key": "service.name", "value": {"stringValue": "otel-lab-generator"}},
      {"key": "deployment.environment", "value": {"stringValue": "lab"}}
    ]},
    "scopeSpans": [{
      "scope": {"name": "manual-curl", "version": "1.0"},
      "spans": [{
        "traceId": "7b6af9d02f3a4c1e8d5b6a7c8d9e0f10",
        "spanId": "a1b2c3d4e5f60718",
        "name": "POST /api/checkout",
        "kind": "SPAN_KIND_SERVER",
        "startTimeUnixNano": "'"$(date +%s)000000000"'",
        "endTimeUnixNano":   "'"$(($(date +%s) + 1))000000000"'",
        "status": {"code": "STATUS_CODE_ERROR", "message": "simulated failure"},
        "attributes": [
          {"key": "http.method", "value": {"stringValue": "POST"}},
          {"key": "http.route", "value": {"stringValue": "/api/checkout"}}
        ]
      }]
    }]
  }]
}'

# OTLP/JSON log record.
LOG='{
  "resourceLogs": [{
    "resource": {"attributes": [
      {"key": "service.name", "value": {"stringValue": "otel-lab-generator"}}
    ]},
    "scopeLogs": [{
      "scope": {"name": "manual-curl"},
      "logRecords": [{
        "timeUnixNano": "'"$(date +%s)000000000"'",
        "severityText": "WARN",
        "severityNumber": 13,
        "body": {"stringValue": "lab: synthetic log from generate-telemetry.sh"}
      }]
    }]
  }]
}'

echo "== sending trace =="
curl -sS -o /dev/null -w "  traces  -> HTTP %{http_code}\n" \
  -X POST "http://${HOST}:${PORT}/v1/traces" \
  -H 'Content-Type: application/json' -d "${TRACE}"

echo "== sending log =="
curl -sS -o /dev/null -w "  logs    -> HTTP %{http_code}\n" \
  -X POST "http://${HOST}:${PORT}/v1/logs" \
  -H 'Content-Type: application/json' -d "${LOG}"

echo
echo "Watch the collector: docker compose logs -f collector"
echo "(200 + empty body is SUCCESS for OTLP — check the exporter output, not curl)"
