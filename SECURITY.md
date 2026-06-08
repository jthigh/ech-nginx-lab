# Security Policy

## Supported use

This repository is a lab project for testing NGINX and Encrypted ClientHello behavior.

It is intended for:

- Home lab testing
- Educational use
- Small-scale ECH experiments
- Direct-origin TLS testing

It is not guaranteed to be production safe.

## Sensitive files

Never commit private or generated material.

Do not commit:

```text
.env
certs/
cloudflare/
ech/
letsencrypt/
secrets/
```

Do not commit:

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

## Credentials

This project may use credentials for DNS automation.

Treat the following as sensitive:

- Cloudflare API tokens
- DNS provider tokens
- TLS private keys
- ACME account material
- ECH private/generated key material
- Local `.env` values
- Logs containing tokens or request headers

If a credential is committed, consider it compromised and rotate it immediately.

## Recommended Cloudflare token scope

When using the optional Cloudflare helper script, use the minimum permissions needed for the target zone.

Recommended token characteristics:

- Limit the token to one zone
- Grant only DNS edit permissions needed for that zone
- Do not use a global API key
- Store the token outside Git in `secrets/cloudflare-api-token`
- Restrict file permissions with `chmod 600`

## Reporting a vulnerability

Please report security issues privately.

Do not open a public issue containing:

- API tokens
- Private keys
- TLS private key material
- ECH private/generated key material
- Real DNS provider credentials
- Real internal hostnames or LAN IPs
- Logs containing sensitive headers or tokens

When reporting an issue, include:

- A clear description of the issue
- Reproduction steps
- Affected file or configuration
- Expected behavior
- Actual behavior
- Suggested remediation, if known

## Disclosure expectations

Please allow reasonable time for review and remediation before public disclosure.

## Local pre-commit safety check

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

Review any hits before committing.

## Secret exposure response

If a secret, token, private key, or credential is accidentally committed:

1. Revoke or rotate the exposed credential immediately.
2. Remove the secret from the working tree.
3. Review Git history before publishing.
4. If already pushed publicly, treat the secret as permanently exposed.
5. Do not rely on deleting the file in a later commit.

## Hardening reminders

Before exposing this stack to the internet, review:

- TLS certificate validity
- ECH configuration freshness
- DNS records
- Firewall policy
- Container port bindings
- NGINX configuration
- Docker image provenance
- API token permissions
- File permissions on local secrets

## Production use

This repository is not presented as a production-ready configuration.

Production deployment may require additional review for:

- Patch management
- Certificate renewal
- Key rotation
- Monitoring
- Logging
- Backup and recovery
- Rate limiting
- Abuse handling
- Availability
- Compliance requirements
