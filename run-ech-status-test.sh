#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKDIR="${WORKDIR:-$SCRIPT_DIR}"
IMAGE="${IMAGE:-local/ech-nginx:nginx-1.29.4-openssl-ech}"
TARGET="${TARGET:-127.0.0.1:9444}"
HOSTNAME="${HOSTNAME:-protected.example.com}"
ECH_PEM="${ECH_PEM:-${WORKDIR}/ech/${HOSTNAME}.pem.ech}"
NGINX_CONTAINER="${NGINX_CONTAINER:-ech_nginx_container}"

REQUEST_FILE="${REQUEST_FILE:-/tmp/ech-status-request.txt}"
RESPONSE_FILE="${RESPONSE_FILE:-/tmp/ech-status-response.txt}"
DEBUG_FILE="${DEBUG_FILE:-/tmp/ech-status-debug.txt}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

extract_echconfig() {
  if [ ! -f "$ECH_PEM" ]; then
    fail "ECH PEM not found: $ECH_PEM"
  fi

  if [ -r "$ECH_PEM" ]; then
    awk '
      /^-----BEGIN ECHCONFIG-----/ {inside=1; next}
      /^-----END ECHCONFIG-----/ {inside=0; next}
      inside {gsub(/[[:space:]]/, ""); printf "%s", $0}
      END {print ""}
    ' "$ECH_PEM"
  else
    echo "INFO: ECH PEM is not readable as current user; using sudo to read public ECHCONFIG." >&2
    sudo awk '
      /^-----BEGIN ECHCONFIG-----/ {inside=1; next}
      /^-----END ECHCONFIG-----/ {inside=0; next}
      inside {gsub(/[[:space:]]/, ""); printf "%s", $0}
      END {print ""}
    ' "$ECH_PEM"
  fi
}

cd "$WORKDIR" || fail "Could not cd to $WORKDIR"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  fail "Docker image not found: $IMAGE"
fi

ECHCONFIG="$(extract_echconfig)"

if [ -z "$ECHCONFIG" ]; then
  fail "Failed to extract ECHConfig."
fi

printf 'GET /ech-status HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n' "$HOSTNAME" > "$REQUEST_FILE"

timeout 20s docker run --rm -i --network host \
  "$IMAGE" \
  /opt/openssl-ech/bin/openssl s_client \
    -tls1_3 \
    -connect "$TARGET" \
    -servername "$HOSTNAME" \
    -ech_config_list "$ECHCONFIG" \
  < "$REQUEST_FILE" \
  > "$RESPONSE_FILE" \
  2> "$DEBUG_FILE"

echo
echo "=== ECH status proof lines from response ==="
grep -Ei 'ECH status|SUCCESS|GREASE|NOT_TRIED|Outer SNI|Inner|public|protected' "$RESPONSE_FILE" || true

echo
echo "=== Recent nginx ECH proof lines ==="
docker logs --tail=30 "$NGINX_CONTAINER" 2>/dev/null | grep -E 'ech_status="(SUCCESS|GREASE|NOT_TRIED)"' || true

echo
echo "=== Saved files ==="
ls -l "$REQUEST_FILE" "$RESPONSE_FILE" "$DEBUG_FILE"
