---

name: Bug report
about: Report a reproducible problem with the ECH NGINX lab stack
title: "[Bug]: "
labels: bug
assignees: ""
-------------

## Summary

Describe the problem clearly.

## Environment

Please provide as much as practical.

```text
Operating system:
CPU architecture:
Docker version:
Docker Compose version:
NGINX version:
OpenSSL ECH branch or commit:
DNS provider:
Test client:
Test mode: local / LAN / public internet / relay-fronted
```

## Expected behavior

What did you expect to happen?

## Actual behavior

What actually happened?

## Steps to reproduce

```bash
# Add the commands needed to reproduce the issue.
```

## Relevant command output

Please sanitize before posting.

```text
Paste relevant output here.
```

Useful commands may include:

```bash
docker version
docker compose version
docker compose ps
docker compose logs --tail=100
docker exec ech_nginx_container nginx -t
dig protected.example.com A
dig protected.example.com HTTPS
./ech-test.sh internal
./run-ech-status-test.sh
```

## Security check

Before submitting, confirm:

* [ ] I did not include API tokens.
* [ ] I did not include private keys.
* [ ] I did not include TLS private key material.
* [ ] I did not include ECH private/generated key material.
* [ ] I did not include real internal hostnames or private IP mappings unless intentionally sanitized.
* [ ] I reviewed logs for authentication headers, cookies, tokens, or credentials.

## Additional context

Add any other context that may help.
