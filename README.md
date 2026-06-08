# ECH NGINX Lab Stack

A Docker Compose based lab stack for experimenting with NGINX, OpenSSL ECH support, and Encrypted ClientHello testing.

This repository is intended for learning, testing, and small lab environments. It is not a drop-in production reverse proxy template.

## What this project does

This stack builds and runs an NGINX container configured for direct TLS termination and ECH testing.

It includes:

- A custom NGINX build container
- Example NGINX TLS/ECH configuration
- Docker Compose deployment file
- Static test content
- ECH status endpoints
- Helper scripts for local/internal and external ECH testing
- Optional Cloudflare DNS upsert helper for A and HTTPS records

## What this project does not include

This repository intentionally does not include private or generated material.

Do not commit:

```text
.env
certs/
cloudflare/
ech/
letsencrypt/
secrets/
```

The following files are also intentionally excluded:

```text
*.key
*.pem
*.pfx
*.p12
*.crt
*.csr
*.tar.gz
*.zip
*.bak
*.backup
*.log
```

## Repository layout

```text
.
├── .dockerignore
├── .env.example
├── .gitignore
├── Dockerfile
├── Dockerfile.curl-ech
├── LICENSE
├── README.md
├── SECURITY.md
├── cf-ech-dns-upsert.py
├── conf.d/
│   └── echtest.conf
├── docker-compose.yml
├── ech-test.sh
├── mime.types
├── nginx.conf
├── run-ech-status-test.sh
└── site-content/
    └── index.html
```

## Prerequisites

You need:

- Docker Engine
- Docker Compose plugin
- A domain you control
- DNS access for that domain
- TLS certificate and private key material for your test hostname
- ECH-capable test tooling

Optional:

- Cloudflare DNS API token if using `cf-ech-dns-upsert.py`

## Local setup

Clone the repository:

```bash
git clone https://github.com/YOUR-GITHUB-USER/YOUR-REPO-NAME.git
cd YOUR-REPO-NAME
```

Create your local environment file:

```bash
cp .env.example .env
nano .env
```

Create local-only private directories:

```bash
mkdir -p certs cloudflare ech letsencrypt secrets
chmod 700 cloudflare secrets
```

Place your TLS certificate and key here:

```text
certs/fullchain.pem
certs/privkey.pem
```

Place your generated ECH PEM file here:

```text
ech/protected.example.com.pem.ech
```

If using the Cloudflare helper script, place a raw Cloudflare API token in:

```text
secrets/cloudflare-api-token
```

Restrict permissions:

```bash
chmod 600 secrets/cloudflare-api-token 2>/dev/null || true
chmod 600 certs/* 2>/dev/null || true
chmod 600 ech/* 2>/dev/null || true
```

## Configure hostnames

The example configuration uses:

```text
protected.example.com
public.example.com
```

Replace those with names under your own domain.

Typical model:

```text
protected.example.com  - the inner/protected ECH hostname
public.example.com     - the public cover name
```

Review and adjust:

```bash
nano .env
nano conf.d/echtest.conf
```

## Validate the Compose configuration

```bash
docker compose config
```

## Build and start

```bash
docker compose up -d --build
```

Check container status:

```bash
docker compose ps
```

Review logs:

```bash
docker compose logs --tail=100
```

## Test the NGINX configuration

```bash
docker exec ech_nginx_container nginx -t
```

Or from the host:

```bash
docker compose exec ech-nginx nginx -t
```

## Run ECH status test

Basic OpenSSL-based test:

```bash
./run-ech-status-test.sh
```

Full curl-based helper:

```bash
./ech-test.sh internal
```

External/DNS-path test:

```bash
./ech-test.sh external
```

Useful environment overrides:

```bash
PROTECTED_NAME=protected.example.com \
PUBLIC_NAME=public.example.com \
INTERNAL_CONNECT_IP=127.0.0.1 \
INTERNAL_PORT=9444 \
./ech-test.sh internal
```

## Optional Cloudflare DNS update

The helper script can upsert A records and an HTTPS record containing the ECHConfig value.

Required environment values:

```bash
export CLOUDFLARE_ZONE_NAME="example.com"
export PROTECTED_NAME="protected.example.com"
export PUBLIC_NAME="public.example.com"
export CLOUDFLARE_API_TOKEN_FILE="./secrets/cloudflare-api-token"
export ECH_CONFIG_FILE="./ech/protected.example.com.pem.ech"
```

Run:

```bash
./cf-ech-dns-upsert.py
```

Optional override for public IPv4:

```bash
PUBLIC_IPV4="203.0.113.10" ./cf-ech-dns-upsert.py
```

## Security notes

This project deals with TLS private keys, ECH configuration material, and DNS provider credentials.

Before committing changes, run:

```bash
git status --short

echo
echo "=== Files tracked by Git ==="
git ls-files

echo
echo "=== Sensitive-content scan ==="
grep -RInE \
  'jthigh|rp[0-9]+|192\.168\.|10\.[0-9]+\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|/home/ubuntu|cloudflare\.ini|privkey|fullchain|letsencrypt|certbot|token|secret|password|PRIVATE KEY|BEGIN .*PRIVATE KEY' \
  . \
  --exclude-dir='.git' || true

echo
echo "=== Forbidden-file scan ==="
find . -type f \( \
  -name '.env' -o \
  -name '*.pem' -o \
  -name '*.key' -o \
  -name '*.pfx' -o \
  -name '*.p12' -o \
  -name '*.crt' -o \
  -name '*.csr' -o \
  -name '*.tar.gz' \
\) -print
```

Expected result: no real secrets, private keys, real private hostnames, real LAN IPs, or local-only files should appear.

If a secret is accidentally committed, consider it compromised and rotate it.

## Updating

Pull changes:

```bash
git pull
```

Rebuild:

```bash
docker compose up -d --build
```

Review logs:

```bash
docker compose logs --tail=100
```

## Troubleshooting

Show effective Compose configuration:

```bash
docker compose config
```

Show container status:

```bash
docker compose ps
```

Show recent logs:

```bash
docker compose logs --tail=200
```

Rebuild without cache:

```bash
docker compose build --no-cache
docker compose up -d
```

Check listening ports on the Docker host:

```bash
sudo ss -lntp
```

Check generated DNS records:

```bash
dig protected.example.com A
dig protected.example.com HTTPS
dig public.example.com A
```

## References

- Docker Engine documentation: https://docs.docker.com/engine/
- Docker Compose documentation: https://docs.docker.com/compose/
- NGINX documentation: https://nginx.org/en/docs/
- OpenSSL documentation: https://docs.openssl.org/
- Cloudflare DNS API documentation: https://developers.cloudflare.com/api/resources/dns/
- GitHub secret scanning documentation: https://docs.github.com/en/code-security/secret-scanning

## License

This project is licensed under the MIT License. See `LICENSE`.
