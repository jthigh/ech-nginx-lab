# Pull request

## Summary

Describe the change.

## Type of change

* [ ] Documentation update
* [ ] Bug fix
* [ ] Feature or enhancement
* [ ] Docker Compose change
* [ ] NGINX configuration change
* [ ] ECH/OpenSSL testing change
* [ ] DNS/HTTPS record handling change
* [ ] Security hardening change
* [ ] Other

## Related issue

Link any related issue.

## Testing performed

Describe what you tested.

```bash
docker compose config
docker compose ps
docker compose logs --tail=100
docker exec ech_nginx_container nginx -t
./ech-test.sh internal
./run-ech-status-test.sh
```

## Security and privacy checklist

* [ ] I did not include API tokens.
* [ ] I did not include private keys.
* [ ] I did not include TLS private key material.
* [ ] I did not include ECH private/generated key material.
* [ ] I did not include real DNS provider credentials.
* [ ] I did not include real internal hostnames or private IP mappings unless intentionally sanitized.
* [ ] I reviewed logs and output for authentication headers, cookies, tokens, and credentials.
* [ ] Example values use safe placeholders such as `example.com`, `protected.example.com`, `public.example.com`, or documentation IP ranges.

## ECH-specific considerations

Does this change affect any of the following?

* [ ] TLS termination location
* [ ] ECH key/config handling
* [ ] DNS HTTPS/SVCB records
* [ ] SNI privacy
* [ ] Destination IP visibility
* [ ] CDN/WAF involvement
* [ ] Relay or tunnel trust boundaries
* [ ] NGINX server block behavior
* [ ] curl/OpenSSL validation behavior

## Documentation

* [ ] README updated if needed
* [ ] SECURITY.md updated if needed
* [ ] CONTRIBUTING.md updated if needed
* [ ] Comments or examples updated if needed

## Additional notes

Add anything else reviewers should know.
