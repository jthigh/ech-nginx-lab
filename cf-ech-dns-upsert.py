#!/usr/bin/env python3

import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


BASE = "https://api.cloudflare.com/client/v4"


def env(name: str, default: str) -> str:
    value = os.environ.get(name, "").strip()
    return value if value else default


ZONE_NAME = env("CLOUDFLARE_ZONE_NAME", "example.com")
PROTECTED_NAME = env("PROTECTED_NAME", "protected.example.com")
PUBLIC_NAME = env("PUBLIC_NAME", "public.example.com")
HTTPS_RECORD_NAME = env("HTTPS_RECORD_NAME", PROTECTED_NAME)

HOSTS = [
    host.strip()
    for host in env("ECH_A_RECORD_NAMES", f"{PROTECTED_NAME},{PUBLIC_NAME}").split(",")
    if host.strip()
]

TOKEN_FILE = Path(env("CLOUDFLARE_API_TOKEN_FILE", "./secrets/cloudflare-api-token"))
ECH_FILE = Path(env("ECH_CONFIG_FILE", f"./ech/{PROTECTED_NAME}.pem.ech"))
PUBLIC_IPV4 = os.environ.get("PUBLIC_IPV4", "").strip()


def read_token() -> str:
    if not TOKEN_FILE.exists():
        raise SystemExit(f"Cloudflare API token file not found: {TOKEN_FILE}")

    token = TOKEN_FILE.read_text(encoding="utf-8").strip()

    if not token:
        raise SystemExit(f"Cloudflare API token file is empty: {TOKEN_FILE}")

    if "\n" in token or "\r" in token:
        raise SystemExit(
            "Cloudflare API token file must contain only the raw token on one line."
        )

    return token


def cf_request(token: str, method: str, path: str, payload: dict | None = None) -> dict:
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    if payload is not None:
        data = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(
        BASE + path,
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Cloudflare API HTTP {e.code}: {body}") from e

    if not result.get("success"):
        raise SystemExit(json.dumps(result, indent=2))

    return result


def get_zone_id(token: str) -> str:
    query = urllib.parse.urlencode({"name": ZONE_NAME, "status": "active"})
    result = cf_request(token, "GET", f"/zones?{query}")
    zones = result.get("result", [])

    if not zones:
        raise SystemExit(f"No active Cloudflare zone found for {ZONE_NAME}")

    return zones[0]["id"]


def get_public_ipv4() -> str:
    if PUBLIC_IPV4:
        if re.fullmatch(r"(?:\d{1,3}\.){3}\d{1,3}", PUBLIC_IPV4):
            return PUBLIC_IPV4
        raise SystemExit(f"PUBLIC_IPV4 is not a valid IPv4 address: {PUBLIC_IPV4}")

    with urllib.request.urlopen("https://cloudflare.com/cdn-cgi/trace", timeout=30) as resp:
        text = resp.read().decode("utf-8", errors="replace")

    for line in text.splitlines():
        if line.startswith("ip="):
            ip = line.split("=", 1)[1].strip()
            if re.fullmatch(r"(?:\d{1,3}\.){3}\d{1,3}", ip):
                return ip

    raise SystemExit("Could not determine public IPv4 address")


def extract_echconfig() -> str:
    if not ECH_FILE.exists():
        raise SystemExit(f"ECH config file not found: {ECH_FILE}")

    text = ECH_FILE.read_text(encoding="utf-8")
    match = re.search(
        r"-----BEGIN ECHCONFIG-----\s*(.*?)\s*-----END ECHCONFIG-----",
        text,
        re.S,
    )

    if not match:
        raise SystemExit(f"Could not find ECHCONFIG block in {ECH_FILE}")

    echconfig = re.sub(r"\s+", "", match.group(1))

    if not echconfig:
        raise SystemExit("ECHCONFIG block was empty")

    return echconfig


def find_record(token: str, zone_id: str, record_type: str, name: str) -> dict | None:
    query = urllib.parse.urlencode({"type": record_type, "name": name})
    result = cf_request(token, "GET", f"/zones/{zone_id}/dns_records?{query}")
    records = result.get("result", [])

    if not records:
        return None

    return records[0]


def upsert_record(token: str, zone_id: str, record_type: str, name: str, payload: dict) -> None:
    existing = find_record(token, zone_id, record_type, name)

    if existing:
        record_id = existing["id"]
        result = cf_request(token, "PUT", f"/zones/{zone_id}/dns_records/{record_id}", payload)
        action = "updated"
    else:
        result = cf_request(token, "POST", f"/zones/{zone_id}/dns_records", payload)
        action = "created"

    record = result["result"]
    print(f"{action.upper()}: {record['type']} {record['name']} -> {record.get('content', record.get('data'))}")


def main() -> None:
    token = read_token()
    zone_id = get_zone_id(token)
    public_ip = get_public_ipv4()
    echconfig = extract_echconfig()

    print(f"Zone: {ZONE_NAME}")
    print(f"Zone ID: {zone_id}")
    print(f"Detected public IPv4: {public_ip}")
    print(f"ECHConfig length: {len(echconfig)}")
    print()

    for host in HOSTS:
        payload = {
            "type": "A",
            "name": host,
            "content": public_ip,
            "ttl": 60,
            "proxied": False,
            "comment": "ECH origin test; DNS-only; bypass provider proxy",
        }
        upsert_record(token, zone_id, "A", host, payload)

    https_payload = {
        "type": "HTTPS",
        "name": HTTPS_RECORD_NAME,
        "ttl": 60,
        "data": {
            "priority": 1,
            "target": ".",
            "value": f"ech={echconfig}",
        },
        "comment": "ECHConfig for direct-origin nginx ECH test",
    }
    upsert_record(token, zone_id, "HTTPS", HTTPS_RECORD_NAME, https_payload)


if __name__ == "__main__":
    main()
