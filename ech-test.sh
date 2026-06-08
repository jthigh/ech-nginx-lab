#!/usr/bin/env bash

set -Eeuo pipefail

MODE="${1:-internal}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORKDIR="${WORKDIR:-$SCRIPT_DIR}"

PROTECTED_NAME="${PROTECTED_NAME:-protected.example.com}"
PUBLIC_NAME="${PUBLIC_NAME:-public.example.com}"

INTERNAL_CONNECT_IP="${INTERNAL_CONNECT_IP:-127.0.0.1}"
INTERNAL_PORT="${INTERNAL_PORT:-9444}"
INTERNAL_DNS_SERVER="${INTERNAL_DNS_SERVER:-$INTERNAL_CONNECT_IP}"

PUBLIC_DNS_SERVER="${PUBLIC_DNS_SERVER:-1.1.1.1}"
EXTERNAL_PORT="${EXTERNAL_PORT:-443}"

CURL_ECH_IMAGE="${CURL_ECH_IMAGE:-local/curl-ech:curl-8.20.0-openssl-ech}"
NGINX_CONTAINER="${NGINX_CONTAINER:-ech_nginx_container}"

ECH_PEM="${ECH_PEM:-${WORKDIR}/ech/${PROTECTED_NAME}.pem.ech}"

HOST_OUTDIR="${HOST_OUTDIR:-/tmp/ech-test}"
CONTAINER_OUTDIR="/out"

PLAIN_HEADERS_HOST="${HOST_OUTDIR}/plain-headers.txt"
PLAIN_BODY_HOST="${HOST_OUTDIR}/plain-body.html"
PLAIN_VERBOSE_HOST="${HOST_OUTDIR}/plain-curl-verbose.txt"

ECH_HEADERS_HOST="${HOST_OUTDIR}/headers.txt"
ECH_BODY_HOST="${HOST_OUTDIR}/body.html"
ECH_VERBOSE_HOST="${HOST_OUTDIR}/curl-verbose.txt"

PLAIN_HEADERS_CONTAINER="${CONTAINER_OUTDIR}/plain-headers.txt"
PLAIN_BODY_CONTAINER="${CONTAINER_OUTDIR}/plain-body.html"

ECH_HEADERS_CONTAINER="${CONTAINER_OUTDIR}/headers.txt"
ECH_BODY_CONTAINER="${CONTAINER_OUTDIR}/body.html"

line() {
  printf '%s\n' "========================================================================"
}

section() {
  echo
  line
  echo "$1"
  line
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARNING: $*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
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
    sudo awk '
      /^-----BEGIN ECHCONFIG-----/ {inside=1; next}
      /^-----END ECHCONFIG-----/ {inside=0; next}
      inside {gsub(/[[:space:]]/, ""); printf "%s", $0}
      END {print ""}
    ' "$ECH_PEM"
  fi
}

prepare_output_dir() {
  mkdir -p "$HOST_OUTDIR"
  chmod 755 "$HOST_OUTDIR"

  rm -f \
    "$PLAIN_HEADERS_HOST" \
    "$PLAIN_BODY_HOST" \
    "$PLAIN_VERBOSE_HOST" \
    "$ECH_HEADERS_HOST" \
    "$ECH_BODY_HOST" \
    "$ECH_VERBOSE_HOST"
}

resolve_public_ip() {
  dig @"$PUBLIC_DNS_SERVER" "$PROTECTED_NAME" A +short | tail -n 1
}

print_mode_plan() {
  section "Test plan"

  case "$MODE" in
    internal)
      echo "Mode:              internal"
      echo "Protected name:    ${PROTECTED_NAME}"
      echo "Public cover name: ${PUBLIC_NAME}"
      echo "Connect IP:        ${INTERNAL_CONNECT_IP}"
      echo "Connect port:      ${INTERNAL_PORT}"
      echo "URL:               https://${PROTECTED_NAME}:${INTERNAL_PORT}/ech-status"
      ;;
    external)
      PUBLIC_IP="$(resolve_public_ip)"
      if [ -z "$PUBLIC_IP" ]; then
        fail "Could not resolve public A record for ${PROTECTED_NAME} using ${PUBLIC_DNS_SERVER}"
      fi

      echo "Mode:              external"
      echo "Protected name:    ${PROTECTED_NAME}"
      echo "Public cover name: ${PUBLIC_NAME}"
      echo "Public DNS server: ${PUBLIC_DNS_SERVER}"
      echo "Public A record:   ${PUBLIC_IP}"
      echo "Connect port:      ${EXTERNAL_PORT}"
      echo "URL:               https://${PROTECTED_NAME}/ech-status"
      echo
      warn "External mode may be a NAT hairpin test if run from the same LAN as the origin."
      ;;
    *)
      fail "Unsupported mode: ${MODE}. Use: internal or external"
      ;;
  esac
}

check_prereqs() {
  section "Prerequisite checks"

  require_cmd docker
  require_cmd dig

  if [ ! -d "$WORKDIR" ]; then
    fail "Workdir not found: $WORKDIR"
  fi

  cd "$WORKDIR" || fail "Could not cd to $WORKDIR"

  echo "Hostname: $(hostname)"
  echo "Workdir:  $(pwd)"

  if ! docker image inspect "$CURL_ECH_IMAGE" >/dev/null 2>&1; then
    fail "Missing Docker image: ${CURL_ECH_IMAGE}"
  fi

  if ! docker ps --format '{{.Names}}' | grep -qx "$NGINX_CONTAINER"; then
    warn "Container ${NGINX_CONTAINER} is not currently running."
  fi

  echo
  echo "ECH curl image:"
  docker run --rm "$CURL_ECH_IMAGE" /opt/curl-ech/bin/curl -V | sed -n '1,5p'
}

dns_checks() {
  section "DNS checks"

  echo "Internal resolver check via ${INTERNAL_DNS_SERVER}:"
  dig @"$INTERNAL_DNS_SERVER" "$PROTECTED_NAME" A +short || true
  dig @"$INTERNAL_DNS_SERVER" "$PROTECTED_NAME" HTTPS +short || true

  echo
  echo "Public resolver check via ${PUBLIC_DNS_SERVER}:"
  dig @"$PUBLIC_DNS_SERVER" "$PROTECTED_NAME" A +short || true
  dig @"$PUBLIC_DNS_SERVER" "$PROTECTED_NAME" HTTPS +short || true
}

get_url_and_resolve_arg() {
  case "$MODE" in
    internal)
      URL="https://${PROTECTED_NAME}:${INTERNAL_PORT}/ech-status"
      RESOLVE_ARG="${PROTECTED_NAME}:${INTERNAL_PORT}:${INTERNAL_CONNECT_IP}"
      ;;
    external)
      PUBLIC_IP="$(resolve_public_ip)"
      if [ -z "$PUBLIC_IP" ]; then
        fail "Could not resolve public A record for ${PROTECTED_NAME} using ${PUBLIC_DNS_SERVER}"
      fi
      URL="https://${PROTECTED_NAME}/ech-status"
      RESOLVE_ARG="${PROTECTED_NAME}:${EXTERNAL_PORT}:${PUBLIC_IP}"
      ;;
  esac
}

plain_tls_check() {
  section "Plain TLS check without ECH"

  get_url_and_resolve_arg

  echo "URL:       $URL"
  echo "Resolve:   $RESOLVE_ARG"
  echo "Expected:  X-ECH-Status should usually be NOT_TRIED"
  echo

  docker run --rm --network host \
    --user "$(id -u):$(id -g)" \
    -v "${HOST_OUTDIR}:${CONTAINER_OUTDIR}" \
    "$CURL_ECH_IMAGE" \
    /opt/curl-ech/bin/curl -skS -v \
      -D "$PLAIN_HEADERS_CONTAINER" \
      -o "$PLAIN_BODY_CONTAINER" \
      --resolve "$RESOLVE_ARG" \
      "$URL" \
      2> "$PLAIN_VERBOSE_HOST"

  CURL_RC=$?
  echo "curl exit code: $CURL_RC"

  echo
  echo "Plain TLS verbose proof lines:"
  grep -aEi 'ECH:|SSL connection|subject:|issuer:|OpenSSL verify|error' "$PLAIN_VERBOSE_HOST" || true

  echo
  echo "Plain TLS response headers:"
  grep -aEi 'HTTP/|X-ECH|X-TLS|Server:|Date:' "$PLAIN_HEADERS_HOST" || true

  echo
  echo "Plain TLS body proof lines:"
  grep -aEi 'ECH status|SUCCESS|GREASE|NOT_TRIED|Outer SNI|Inner|public|protected' "$PLAIN_BODY_HOST" || true
}

ech_curl_check() {
  section "ECH curl check"

  ECHCONFIG="$(extract_echconfig)"

  if [ -z "$ECHCONFIG" ]; then
    fail "ECHConfig extraction failed."
  fi

  get_url_and_resolve_arg

  echo "ECHConfig length: ${#ECHCONFIG}"
  echo "URL:              $URL"
  echo "Resolve:          $RESOLVE_ARG"
  echo "ECH public name:  $PUBLIC_NAME"
  echo "Expected:         X-ECH-Status should be SUCCESS"
  echo

  docker run --rm --network host \
    --user "$(id -u):$(id -g)" \
    -e ECHCONFIG="$ECHCONFIG" \
    -e LD_LIBRARY_PATH="/opt/openssl-ech/lib64:/opt/openssl-ech/lib" \
    -v "${HOST_OUTDIR}:${CONTAINER_OUTDIR}" \
    "$CURL_ECH_IMAGE" \
    /opt/curl-ech/bin/curl -skS -v \
      --tlsv1.3 \
      --ech "ecl:${ECHCONFIG}" \
      --ech "pn:${PUBLIC_NAME}" \
      -D "$ECH_HEADERS_CONTAINER" \
      -o "$ECH_BODY_CONTAINER" \
      --resolve "$RESOLVE_ARG" \
      "$URL" \
      2> "$ECH_VERBOSE_HOST"

  CURL_RC=$?
  echo "curl exit code: $CURL_RC"

  echo
  echo "ECH curl verbose proof lines:"
  grep -aEi 'ECH:|SSL connection|subject:|issuer:|OpenSSL verify|error' "$ECH_VERBOSE_HOST" || true

  echo
  echo "ECH response headers:"
  grep -aEi 'HTTP/|X-ECH|X-TLS|Server:|Date:' "$ECH_HEADERS_HOST" || true

  echo
  echo "ECH response body proof lines:"
  grep -aEi 'ECH status|SUCCESS|GREASE|NOT_TRIED|Outer SNI|Inner|public|protected' "$ECH_BODY_HOST" || true

  if grep -aq 'X-ECH-Status: SUCCESS' "$ECH_HEADERS_HOST"; then
    echo
    echo "PASS: ECH curl request returned X-ECH-Status: SUCCESS"
  else
    echo
    warn "ECH curl request did not return X-ECH-Status: SUCCESS"
  fi
}

nginx_log_check() {
  section "Recent nginx proof lines"

  docker logs --tail=40 "$NGINX_CONTAINER" 2>/dev/null \
    | grep -E 'ech_status="(SUCCESS|GREASE|NOT_TRIED|FAILED|BACKEND)"' \
    || true
}

summary() {
  section "Saved output files"

  ls -l "$HOST_OUTDIR" || true

  echo
  echo "Most important files:"
  echo "  $PLAIN_HEADERS_HOST"
  echo "  $PLAIN_BODY_HOST"
  echo "  $PLAIN_VERBOSE_HOST"
  echo "  $ECH_HEADERS_HOST"
  echo "  $ECH_BODY_HOST"
  echo "  $ECH_VERBOSE_HOST"
}

prepare_output_dir
print_mode_plan
check_prereqs
dns_checks
plain_tls_check
ech_curl_check
nginx_log_check
summary
