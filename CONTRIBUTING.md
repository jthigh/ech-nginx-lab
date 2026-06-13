# Contributing

Thank you for your interest in contributing to this project.

This repository is a lab-focused project for testing direct-origin Encrypted ClientHello with NGINX, OpenSSL, Docker Compose, DNS HTTPS records, and related validation tooling.

The goal is to keep the project practical, reproducible, security-conscious, and useful to people who want to experiment with ECH without requiring CDN/WAF TLS termination.

## Ways to contribute

Useful contributions include:

* Bug reports
* Documentation improvements
* Test results from different environments
* Safer or clearer Docker Compose patterns
* NGINX configuration improvements
* OpenSSL/ECH build improvements
* DNS HTTPS/SVCB record examples
* Cloudflare DNS automation improvements
* Additional ECH validation commands
* Relay-fronted direct-origin ECH test patterns
* Clear notes about what worked, what failed, and why

Small, focused contributions are preferred.

## Before opening an issue

Please check:

* Existing issues
* Existing pull requests
* The README
* The security policy
* The current example configuration

When possible, include the exact command you ran and the relevant output.

## Reporting bugs

When reporting a bug, please include:

* Operating system and version
* CPU architecture
* Docker version
* Docker Compose version
* NGINX version used by the build
* OpenSSL ECH branch or commit used by the build
* Browser, curl, or OpenSSL test client used
* DNS provider used
* Whether the test is local, LAN, public internet, or relay-fronted
* Expected behavior
* Actual behavior
* Relevant logs or command output

Do not include secrets, tokens, private keys, real production hostnames, or sensitive logs.

Good bug reports usually include commands such as:

```bash
docker version
docker compose version
docker compose ps
docker compose logs --tail=100
docker exec ech_nginx_container nginx -t
dig protected.example.com HTTPS
dig protected.example.com A
./ech-test.sh internal
./run-ech-status-test.sh
```

Sanitize output before posting it publicly.

## Requesting features

Feature requests are welcome when they are related to the project scope.

Helpful feature requests include:

* The problem you are trying to solve
* Why the current project does not address it
* The environment where you want to use it
* Any relevant standards, tools, or examples
* Whether you are willing to test or contribute the change

This project is intentionally lab-oriented, so features that improve clarity, reproducibility, and testability are more likely to fit than features that turn it into a full production platform.

## Security-sensitive reports

Do not open a public issue containing:

* API tokens
* Private keys
* TLS private key material
* ECH private/generated key material
* Real DNS provider credentials
* Real internal hostnames or private IP mappings
* Logs containing authentication headers, cookies, tokens, or credentials

For security-sensitive reports, follow `SECURITY.md`.

If a secret is accidentally posted, assume it is compromised and rotate it immediately.

## Development workflow

Fork the repository and create a branch:

```bash
git clone https://github.com/YOUR-GITHUB-USER/ech-nginx-lab.git
cd ech-nginx-lab

git checkout -b your-change-name
```

Make your changes, then run basic checks.

Recommended checks:

```bash
docker compose config

grep -RInE \
  'jthigh|rp[0-9]+|192\.168\.|10\.[0-9]+\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|/home/ubuntu|cloudflare\.ini|privkey|fullchain|letsencrypt|certbot|token|secret|password|PRIVATE KEY|BEGIN .*PRIVATE KEY' \
  . \
  --exclude-dir='.git' || true

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

Review all hits before committing.

## Commit guidance

Use clear commit messages.

Examples:

```text
Improve ECH status test output
Document Cloudflare HTTPS record setup
Add relay-fronted ECH notes
Clarify private key handling
Fix Docker Compose healthcheck
```

Avoid large unrelated commits. A small focused pull request is easier to review.

## Pull request checklist

Before opening a pull request, confirm:

* The change is related to direct-origin ECH testing
* The change does not include secrets or private key material
* The change does not include real private infrastructure details
* Documentation has been updated where needed
* Example values use safe placeholders
* Scripts are executable when needed
* `docker compose config` succeeds if Compose files were changed
* Security-sensitive details have been removed or sanitized

## Placeholder values

Use documentation-safe examples such as:

```text
example.com
protected.example.com
public.example.com
203.0.113.10
192.0.2.10
198.51.100.10
```

Do not use real production domains, real private IP maps, or real personal infrastructure names unless there is a specific reason and you are comfortable publishing them.

## Coding style

For shell scripts:

* Use clear variable names
* Prefer explicit error messages
* Keep commands easy to copy and run
* Avoid unnecessary dependencies
* Avoid embedding environment-specific paths
* Prefer environment variable overrides for local customization

For Python scripts:

* Keep dependencies minimal
* Prefer standard library when reasonable
* Use clear error handling
* Avoid hard-coded personal paths or domains
* Read local secrets from ignored files or environment variables
* Do not print secrets

For Docker Compose examples:

* Prefer explicit service names
* Use `.env.example` for documented variables
* Do not commit `.env`
* Avoid privileged containers unless clearly justified
* Use read-only mounts where practical
* Use minimal capabilities where practical
* Document exposed ports clearly

## Documentation style

Documentation should be:

* Practical
* Command-line focused
* Reproducible
* Honest about limitations
* Clear about security tradeoffs
* Careful with terminology

When documenting ECH behavior, distinguish between:

* DNS privacy
* SNI privacy
* Destination IP visibility
* TLS termination location
* CDN/WAF involvement
* Relay or tunnel trust boundaries

## Project scope

In scope:

* Direct-origin ECH testing
* NGINX/OpenSSL ECH lab patterns
* Docker Compose examples
* DNS HTTPS/SVCB ECH records
* Cloudflare DNS-only automation
* curl/OpenSSL ECH validation
* Optional TCP relay or tunnel-fronted origin patterns
* Documentation of tradeoffs and test results

Out of scope:

* Production support guarantees
* Managed CDN/WAF replacement
* Kubernetes deployments
* Full certificate lifecycle automation
* Full DNS provider abstraction
* General-purpose reverse proxy management
* Support for unsafe or malicious use

## Code of conduct

All participation is subject to `CODE_OF_CONDUCT.md`.

Keep discussions respectful, technical, and focused on improving the project.

## License

By contributing, you agree that your contributions will be licensed under the MIT License used by this repository.
