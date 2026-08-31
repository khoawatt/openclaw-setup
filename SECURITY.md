# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| main    | ✅        |

## Reporting a Vulnerability

Do not open a public issue for security vulnerabilities. Contact the maintainer via GitHub (@khoawatt) or open a private security advisory at `https://github.com/khoawatt/openclaw-setup/security/advisories/new`.

## Secrets Policy

This repository is **secrets-free by design**. No real credentials are committed:

* `openclaw.json` — local gateway config, gitignored
* `watcher/conf/telegram.env` — bot token, gitignored, `chmod 600`
* Memory archives — private tarballs, never committed

Run `bash scripts/verify-no-secrets.sh` before any push.
